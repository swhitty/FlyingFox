//
//  SocketPool+kQueueTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 10/09/2022.
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

#if canImport(Darwin)
@testable import FlyingSocks
import Foundation
import Testing

struct kQueueTests {

    @Test
    func queueCloses() throws {
        var queue = try kQueue.make()
        #expect(throws: Never.self) {
            try queue.stop()
        }
    }

    @Test
    func queueThrowsError_Closes() throws {
        #expect(throws: SocketError.self) {
            try kQueue.closeQueue(file: .validMock)
        }
    }

    @Test
    func queueThrowsError_Make() throws {
        #expect(throws: SocketError.self) {
            try kQueue.makeQueue(file: -1)
        }
    }

    @Test
    func addingEventToInvalidDescriptor_ThrowsError() throws {
        let queue = try kQueue.make()

        #expect(throws: SocketError.self) {
            try queue.addEvent(.read, for: .validMock)
        }
    }

    @Test
    func addingAndRemovingEvents() throws {
        var queue = try kQueue.make()
        let (s1, _) = try Socket.makeNonBlockingPair()

        #expect(throws: Never.self) {
            try queue.addEvents(.connection, for: s1.file)
        }
        #expect(queue.existing[s1.file] == .connection)

        #expect(throws: Never.self) {
            try queue.removeEvents(.connection, for: s1.file)
        }
        #expect(queue.existing[s1.file] == nil)
    }

    @Test
    func removingEventToInvalidDescriptor_ThrowsError() throws {
        let queue = try kQueue.make()

        #expect(throws: SocketError.self) {
            try queue.removeEvent(.read, for: .validMock)
        }
    }

    @Test
    func filterEvents() {
        #expect(
            Socket.Event.read.kqueueFilter == Int16(EVFILT_READ)
        )
        #expect(
            Socket.Event.write.kqueueFilter == Int16(EVFILT_WRITE)
        )
        #expect(
            Socket.Event.make(from: Int16(EVFILT_READ)) == .read
        )
        #expect(
            Socket.Event.make(from: Int16(EVFILT_WRITE)) == .write
        )
        #expect(
            Socket.Event.make(from: 10100) == nil
        )
    }

    @Test
    func readResult_CreatesNotification() {
        #expect(
            EventNotification.make(from: .make(
                ident: 10,
                filter: EVFILT_READ
            )) == EventNotification(
                file: .init(rawValue: 10),
                events: .read,
                errors: []
            )
        )
    }

    @Test
    func readErrors_CreatesNotification() {
        #expect(
            EventNotification.make(from: .make(
                ident: 10,
                filter: EVFILT_READ,
                flags: EV_ERROR
            )) == EventNotification(
                file: .init(rawValue: 10),
                events: .read,
                errors: [.error]
            )
        )
    }

    @Test
    func errorsIgnored_WhenReadWithDataAvailable() {
        #expect(
            EventNotification.make(from: .make(
                ident: 10,
                filter: EVFILT_READ,
                flags: EV_ERROR,
                data: 5
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
            EventNotification.make(from: .make(
                ident: 10,
                filter: EVFILT_WRITE
            )) == EventNotification(
                file: .init(rawValue: 10),
                events: .write,
                errors: []
            )
        )
    }

    @Test
    func writeErrors_CreatesNotification() {
        #expect(
            EventNotification.make(from: .make(
                ident: 10,
                filter: EVFILT_WRITE,
                flags: EV_EOF,
                data: 10
            )) == EventNotification(
                file: .init(rawValue: 10),
                events: .write,
                errors: [.endOfFile]
            )
        )
    }

    @Test
    func invalidFilter_DoesNotCreateNotification() {
        #expect(
            EventNotification.make(from: .make(
                filter: 0
            )) == nil
        )
    }

    @Test
    func queueReturnsEvents() async throws {
        var queue = try kQueue.make()

        let (s1, s2) = try Socket.makeNonBlockingPair()

        try queue.addEvents([.read], for: s2.file)

        let data = Data([10, 20])
        _ = try s1.write(data, from: data.startIndex)

        #expect(
            try await queue.getEvents() == [.init(file: s2.file, events: [.read], errors: [])]
        )
    }

    @Test
    func queueThrowsErrorIfClosed() async throws {
        var queue = try kQueue.make()
        let (s1, _) = try Socket.makeNonBlockingPair()
        try queue.addEvents([.read], for: s1.file)

        try queue.stop()
        await #expect(throws: SocketError.self) {
            try await queue.getEvents()
        }
    }
}

private extension kQueue {

    static func make() throws -> Self {
        var queue = kQueue(maxEvents: 20)
        try queue.open()
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

private extension kevent {
    static func make(ident: UInt = 0,
                     filter: Int32 = EVFILT_READ,
                     flags: Int32 = 0,
                     data: Int = 0) -> Self {
        .init(ident: ident,
              filter: Int16(filter),
              flags: UInt16(flags),
              fflags: 0,
              data: data,
              udata: nil)
    }
}
#endif
