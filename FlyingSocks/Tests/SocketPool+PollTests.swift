//
//  SocketPool+PollTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 25/09/2022.
//  Copyright © 2022 Simon Whitty. All rights reserved.
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/swhitty/FlyingFox
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

@testable import FlyingSocks
import XCTest

final class PollTests: XCTestCase {

    func testInterval() {
        XCTAssertEqual(
            Poll.Interval.immediate.milliseconds,
            0
        )

        XCTAssertEqual(
            Poll.Interval.seconds(1).milliseconds,
            1000
        )
    }

    func testAddingAndRemovingEvents() throws {
        var queue = Poll.make()

        XCTAssertNoThrow(try queue.addEvents(.connection, for: .validMock))
        XCTAssertEqual(queue.entries, [.init(file: .validMock, events: .connection)])

        XCTAssertNoThrow(try queue.removeEvents(.connection, for: .validMock))
        XCTAssertEqual(queue.entries, [])
    }

    func testAddingEventWhenNotOpen_ThrowsError() {
        var queue = Poll.make()
        queue.stop()

        XCTAssertThrowsError(
            try queue.addEvents(.read, for: .validMock)
        )
    }

    func testRemovingEventWhenNotOpen_ThrowsError() {
        var queue = Poll.make()
        queue.stop()

        XCTAssertThrowsError(
            try queue.removeEvents(.read, for: .validMock)
        )
    }

    func testReadEntry_CreatesPollFD() {
        let entry = Poll.Entry(file: .init(rawValue: 10), events: .read)

        XCTAssertEqual(entry.pollfd.fd, 10)
        XCTAssertEqual(entry.pollfd.events, Int16(POLLIN))
        XCTAssertEqual(entry.pollfd.revents, 0)
    }

    func testWriteEntry_CreatesPollFD() {
        let entry = Poll.Entry(file: .init(rawValue: 20), events: .write)

        XCTAssertEqual(entry.pollfd.fd, 20)
        XCTAssertEqual(entry.pollfd.events, Int16(POLLOUT))
        XCTAssertEqual(entry.pollfd.revents, 0)
    }

    func testConnectionEntry_CreatesPollFD() {
        let entry = Poll.Entry(file: .init(rawValue: 30), events: .connection)

        XCTAssertEqual(entry.pollfd.fd, 30)
        XCTAssertEqual(entry.pollfd.events, Int16(POLLOUT | POLLIN))
        XCTAssertEqual(entry.pollfd.revents, 0)
    }

    func testReadResult_CreatesNotification() {
        XCTAssertEqual(
            EventNotification.make(from: pollfd.make(
                fd: 10,
                events: POLLIN,
                revents: POLLIN
            )),
            EventNotification(
                file: .init(rawValue: 10),
                events: .read,
                errors: []
            )
        )
    }

    func testErrorsIgnored_WhenReadWithDataAvailable() {
        XCTAssertEqual(
            EventNotification.make(from: pollfd.make(
                fd: 10,
                events: POLLIN,
                revents: POLLIN | POLLHUP
            )),
            EventNotification(
                file: .init(rawValue: 10),
                events: .read,
                errors: []
            )
        )
    }

    func testWriteResult_CreatesNotification() {
        XCTAssertEqual(
            EventNotification.make(from: pollfd.make(
                fd: 10,
                events: POLLOUT,
                revents: POLLOUT
            )),
            EventNotification(
                file: .init(rawValue: 10),
                events: .write,
                errors: []
            )
        )
    }

    func testWriteHUP_CreatesNotification() {
        XCTAssertEqual(
            EventNotification.make(from: pollfd.make(
                fd: 10,
                events: POLLIN | POLLOUT,
                revents: POLLHUP
            )),
            EventNotification(
                file: .init(rawValue: 10),
                events: .connection,
                errors: [.endOfFile]
            )
        )
    }

    func testWriteErrors_CreatesNotification() {
        XCTAssertEqual(
            EventNotification.make(from: pollfd.make(
                fd: 10,
                events: POLLOUT,
                revents: POLLERR
            )),
            EventNotification(
                file: .init(rawValue: 10),
                events: .write,
                errors: [.error]
            )
        )
    }

    func testUnmatchedRevents_DoesNotCreateNotification() {
        XCTAssertNil(
            EventNotification.make(from: pollfd.make(
                events: POLLIN,
                revents: 0
            ))
        )
        XCTAssertNil(
            EventNotification.make(from: pollfd.make(
                events: POLLIN,
                revents: POLLOUT
            ))
        )
        XCTAssertNil(
            EventNotification.make(from: pollfd.make(
                events: POLLIN | POLLOUT,
                revents: 0
            ))
        )
    }

    func testGetEvents_ReturnsEvents() async throws {
        var queue = Poll.make()

        let (s1, s2) = try Socket.makeNonBlockingPair()

        try queue.addEvents([.read], for: s2.file)

        let data = Data([10, 20])
        _ = try s1.write(data, from: data.startIndex)

        await AsyncAssertEqual(
            try await queue.getEvents(),
            [.init(file: s2.file, events: [.read], errors: [])]
        )
    }

    func testGetEventsWhenNotReady_ThrowsError() async {
        var queue = Poll.make()
        queue.stop()

        await AsyncAssertThrowsError(
            try await queue.getEvents()
        )
    }
}

private extension Poll {

    static func make() -> Self {
        var queue = Poll(interval: .immediate)
        queue.open()
        return queue
    }

    func getEvents() async throws -> [EventNotification] {
        let queue = self
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let result = Result {
                    try queue.getNotifications()
                }
                continuation.resume(with: result)
            }
        }
    }
}

private extension pollfd {
    static func make(fd: Int32 = 0,
                     events: Int32 = POLLIN,
                     revents: Int32 = POLLIN) -> Self {
        .init(fd: fd, events: Int16(events), revents: Int16(revents))
    }
}
