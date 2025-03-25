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
import Foundation
import Testing

struct PollTests {

   @Test
    func interval() {
       #expect(
          Poll.Interval.immediate.milliseconds == 0
       )

       #expect(
          Poll.Interval.seconds(1).milliseconds == 1000
       )
    }

    @Test
    func addingAndRemovingEvents() {
        var queue = Poll.make()

        #expect(throws: Never.self) {
            try queue.addEvents(.connection, for: .validMock)
        }
        #expect(queue.entries == [.init(file: .validMock, events: .connection)])

        #expect(throws: Never.self) {
            try queue.removeEvents(.connection, for: .validMock)
        }
        #expect(queue.entries == [])
    }

    @Test
    func addingEventWhenNotOpen_ThrowsError() {
        var queue = Poll.make()
        queue.stop()

        #expect(throws: SocketError.self) {
            try queue.addEvents(.read, for: .validMock)
        }
    }

    @Test
    func removingEventWhenNotOpen_ThrowsError() {
        var queue = Poll.make()
        queue.stop()

        #expect(throws: SocketError.self) {
            try queue.removeEvents(.read, for: .validMock)
        }
    }

    @Test
    func readEntry_CreatesPollFD() {
        let entry = Poll.Entry(file: .init(rawValue: 10), events: .read)

        #expect(entry.pollfd.fd == 10)
        #expect(entry.pollfd.events == Int16(POLLIN))
        #expect(entry.pollfd.revents == 0)
    }

    @Test
    func writeEntry_CreatesPollFD() {
        let entry = Poll.Entry(file: .init(rawValue: 20), events: .write)

        #expect(entry.pollfd.fd == 20)
        #expect(entry.pollfd.events == Int16(POLLOUT))
        #expect(entry.pollfd.revents == 0)
    }

    @Test
    func connectionEntry_CreatesPollFD() {
        let entry = Poll.Entry(file: .init(rawValue: 30), events: .connection)

        #expect(entry.pollfd.fd == 30)
        #expect(entry.pollfd.events == Int16(POLLOUT | POLLIN))
        #expect(entry.pollfd.revents == 0)
    }

    @Test
    func readResult_CreatesNotification() {
        #expect(
            EventNotification.make(from: pollfd.make(
                fd: 10,
                events: POLLIN,
                revents: POLLIN
            )) == EventNotification(
                file: .init(rawValue: 10),
                events: .read,
                errors: []
            )
        )
    }

    @Test
    func errorsIgnored_WhenReadWithDataAvailable() {
        #expect(
            EventNotification.make(from: pollfd.make(
                fd: 10,
                events: POLLIN,
                revents: POLLIN | POLLHUP
            )) == EventNotification(
                file: .init(rawValue: 10),
                events: .read,
                errors: []
            )
        )
    }

    @Test
    func writeResult_CreatesNotification() {
        #expect(
            EventNotification.make(from: pollfd.make(
                fd: 10,
                events: POLLOUT,
                revents: POLLOUT
            )) == EventNotification(
                file: .init(rawValue: 10),
                events: .write,
                errors: []
            )
        )
    }

    @Test
    func writeHUP_CreatesNotification() {
        #expect(
            EventNotification.make(from: pollfd.make(
                fd: 10,
                events: POLLIN | POLLOUT,
                revents: POLLHUP
            )) == EventNotification(
                file: .init(rawValue: 10),
                events: .connection,
                errors: [.endOfFile]
            )
        )
    }

    @Test
    func writeErrors_CreatesNotification() {
        #expect(
            EventNotification.make(from: pollfd.make(
                fd: 10,
                events: POLLOUT,
                revents: POLLERR
            )) == EventNotification(
                file: .init(rawValue: 10),
                events: .write,
                errors: [.error]
            )
        )
    }

    @Test
    func unmatchedRevents_DoesNotCreateNotification() {
        #expect(
            EventNotification.make(from: pollfd.make(
                events: POLLIN,
                revents: 0
            )) == nil
        )
        #expect(
            EventNotification.make(from: pollfd.make(
                events: POLLIN,
                revents: POLLOUT
            )) == nil
        )
        #expect(
            EventNotification.make(from: pollfd.make(
                events: POLLIN | POLLOUT,
                revents: 0
            )) == nil
        )
    }

    @Test
    func getEvents_ReturnsEvents() async throws {
        var queue = Poll.make()

        let (s1, s2) = try Socket.makeNonBlockingPair()

        try queue.addEvents([.read], for: s2.file)

        let data = Data([10, 20])
        _ = try s1.write(data, from: data.startIndex)

        #expect(
            try await queue.getEvents() == [.init(file: s2.file, events: [.read], errors: [])]
        )
    }

    @Test
    func getEventsWhenNotReady_ThrowsError() async {
        var queue = Poll.make()
        queue.stop()

        await #expect(throws: SocketError.self) {
            try await queue.getEvents()
        }
    }
}

private extension Poll {

    static func make() -> Self {
        var queue = Poll(interval: .immediate)
        queue.open()
        return queue
    }

    func getEvents() async throws -> [EventNotification] {
        let queue = UncheckedSendable(wrappedValue: self)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let result = Result {
                    try queue.wrappedValue.getNotifications()
                }
                continuation.resume(with: result)
            }
        }
    }
}

private extension pollfd {
    static func make(fd: Socket.FileDescriptorType = 0,
                     events: Int32 = POLLIN,
                     revents: Int32 = POLLIN) -> Self {
        .init(fd: fd, events: Int16(events), revents: Int16(revents))
    }
}
