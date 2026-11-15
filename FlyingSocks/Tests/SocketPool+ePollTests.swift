//
//  SocketPool+ePollTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 16/11/2026.
//  Copyright © 2026 Simon Whitty. All rights reserved.
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

#if canImport(CSystemLinux)
@testable import FlyingSocks
import Foundation
import Testing

struct ePollTests {

    @Test
    func stop_WakesWaitingNotifications() async throws {
        var queue = try ePoll.make()
        defer { try? queue.close() }

        // stop a copy sharing the descriptors once the wait below is under way
        nonisolated(unsafe) let stopping = queue
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            var queue = stopping
            try? queue.stop()
        }

        await #expect(throws: SocketError.disconnected) {
            try await queue.getEvents()
        }
    }

    @Test
    func stop_WakesNotificationsStartedAfterwards() throws {
        var queue = try ePoll.make()
        defer { try? queue.close() }
        // a copy taken before stop, like a wait queued but not yet started
        let pending = queue
        try queue.stop()

        #expect(throws: SocketError.disconnected) {
            try pending.getNotifications()
        }
        #expect(throws: SocketError.disconnected) {
            try queue.getNotifications()
        }
    }

    @Test
    func stop_ThrowsWhenAlreadyStopped() throws {
        var queue = try ePoll.make()
        defer { try? queue.close() }
        try queue.stop()

        #expect(throws: SocketError.disconnected) {
            try queue.stop()
        }
    }

    @Test
    func stop_LeavesDescriptorsOpen_UntilClosed() throws {
        var queue = try ePoll.make()
        let file = queue.file
        let canary = queue.canary
        try queue.stop()
        #expect(fcntl(file.rawValue, F_GETFD) != -1)
        #expect(fcntl(canary.rawValue, F_GETFD) != -1)

        // the closed descriptors can be reused at once by a test running in parallel,
        // so only the queue's own state is checked
        try queue.close()
        #expect(queue.file == .invalid)
        #expect(queue.canary == .invalid)
    }

    @Test
    func reopening_AfterClose_Succeeds() throws {
        var queue = try ePoll.make()
        try queue.stop()
        try queue.close()

        try queue.open()
        defer { try? queue.close() }
        #expect(queue.file != .invalid)
        #expect(queue.canary != .invalid)
        #expect(!queue.isStopped)
    }

    @Test
    func close_ClosesCanary() throws {
        let before = try Self.countEventDescriptors()
        for _ in 0..<200 {
            var queue = try ePoll.make()
            try queue.stop()
            try queue.close()
        }

        // each cycle leaked an eventfd before; tests running in parallel can
        // only hold a few at once, so a wide margin still catches the leak
        #expect(try Self.countEventDescriptors() - before < 100)
    }

    @Test
    func closeEventTrigger_ThrowsError() {
        #expect(throws: SocketError.self) {
            try ePoll.closeEventTrigger(file: Socket.FileDescriptor(rawValue: 999))
        }
    }

    static func countEventDescriptors() throws -> Int {
        let fm = FileManager.default
        return try fm.contentsOfDirectory(atPath: "/proc/self/fd").filter {
            (try? fm.destinationOfSymbolicLink(atPath: "/proc/self/fd/\($0)"))?.contains("eventfd") == true
        }.count
    }
}

private extension ePoll {

    static func make() throws -> Self {
        var queue = ePoll(maxEvents: 20)
        try queue.open()
        return queue
    }

    func getEvents() async throws -> [EventNotification] {
        nonisolated(unsafe) let queue = self
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
#endif
