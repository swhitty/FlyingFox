//
//  EventQueueSocketPoolTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 12/09/2022.
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

final class EventQueueSocketPoolTests: XCTestCase {

    typealias Continuation = CancellingContinuation<Void, SocketError>
    typealias Waiting = EventQueueSocketPool<MockEventQueue>.Waiting

#if canImport(Darwin)
    func testKqueuePool() {
        let pool = makeEventQueuePool()
        XCTAssertTrue(type(of: pool) == EventQueueSocketPool<kQueue>.self)
    }
#endif

    func testQueuePrepare() async throws {
        let pool = EventQueueSocketPool.make()

        await AsyncAssertNil(await pool.state)

        try await pool.prepare()
        await AsyncAssertEqual(await pool.state, .ready)
    }

    func testQueueRun_ThrowsError_WhenNotReady() async throws {
        let pool = EventQueueSocketPool.make()

        await AsyncAssertThrowsError(try await pool.run(), of: Error.self)
    }

    func testSuspendedSockets_ThrowError_WhenCancelled() async throws {
        let pool = EventQueueSocketPool.make()
        try await pool.prepare()

        let task = Task {
            let socket = try Socket(domain: AF_UNIX, type: Socket.stream)
            try await pool.suspendSocket(socket, untilReadyFor: .read)
        }

        task.cancel()

        await AsyncAssertThrowsError(try await task.value, of: CancellationError.self)
    }

    func testCancellingPollingPool_CancelsSuspendedSocket() async throws {
        let pool = EventQueueSocketPool.make()
        try await pool.prepare()

        _ = Task(timeout: 0.5) {
            try await pool.run()
        }

        let (s1, s2) = try Socket.makeNonBlockingPair()
        await AsyncAssertThrowsError(
            try await pool.suspendSocket(s1, untilReadyFor: .read),
            of: CancellationError.self
        )
        try s1.close()
        try s2.close()
    }

    func testCancellingPool_CancelsNewSockets() async throws {
        let pool = EventQueueSocketPool.make()
        try await pool.prepare()

        let task = Task(timeout: 0.1) {
            try await pool.run()
        }

        try? await task.value

        let socket = try Socket(domain: AF_UNIX, type: Socket.stream)
        await AsyncAssertThrowsError(
            try await pool.suspendSocket(socket, untilReadyFor: .read)
        )
    }

    func testQueueNotification_ResumesSocket() async throws {
        let pool = EventQueueSocketPool.make()
        try await pool.prepare()
        let task = Task { try await pool.run() }
        defer { task.cancel() }

        let socket = try Socket(domain: AF_UNIX, type: Socket.stream)
        let suspension = Task {
            try await pool.suspendSocket(socket, untilReadyFor: .read)
        }
        defer { suspension.cancel() }

        await pool.queue.sendResult(returning: [
            .init(file: socket.file, events: .read, errors: [])
        ])

        await AsyncAssertNoThrow(
            try await pool.suspendSocket(socket, untilReadyFor: .read)
        )
    }

    func testQueueNotificationError_ResumesSocket_WithError() async throws {
        let pool = EventQueueSocketPool.make()
        try await pool.prepare()
        let task = Task { try await pool.run() }
        defer { task.cancel() }

        let socket = try Socket(domain: AF_UNIX, type: Socket.stream)
        let suspension = Task {
            try await pool.suspendSocket(socket, untilReadyFor: .read)
        }
        defer { suspension.cancel() }

        await pool.queue.sendResult(returning: [
            .init(file: socket.file, events: .read, errors: [.endOfFile])
        ])

        await AsyncAssertThrowsError(
            try await pool.suspendSocket(socket, untilReadyFor: .read),
            of: SocketError.self
        ) { XCTAssertEqual($0, .disconnected) }
    }

    func testWaiting_IsEmpty() {
        let cn = Continuation()

        var waiting = Waiting()
        XCTAssertTrue(waiting.isEmpty)

        _ = waiting.appendContinuation(cn, for: .validMock, events: .read)
        XCTAssertFalse(waiting.isEmpty)

        _ = waiting.removeContinuation(cn, for: .validMock)
        XCTAssertTrue(waiting.isEmpty)
    }

    func testWaitingEvents() {
        var waiting = Waiting()
        let cnRead = Continuation()
        let cnRead1 = Continuation()
        let cnWrite = Continuation()

        XCTAssertEqual(
            waiting.appendContinuation(cnRead, for: .validMock, events: .read),
            [.read]
        )
        XCTAssertEqual(
            waiting.appendContinuation(cnRead1, for: .validMock, events: .read),
            [.read]
        )
        XCTAssertEqual(
            waiting.appendContinuation(cnWrite, for: .validMock, events: .write),
            [.read, .write]
        )
        XCTAssertEqual(
            waiting.removeContinuation(.init(), for: .validMock),
            []
        )
        XCTAssertEqual(
            waiting.removeContinuation(cnWrite, for: .validMock),
            [.write]
        )
        XCTAssertEqual(
            waiting.removeContinuation(cnRead, for: .validMock),
            []
        )
        XCTAssertEqual(
            waiting.removeContinuation(cnRead1, for: .validMock),
            [.read]
        )
    }

    func testWaitingContinuations() {
        var waiting = Waiting()
        let cnRead = Continuation()
        let cnRead1 = Continuation()
        let cnWrite = Continuation()

        _ = waiting.appendContinuation(cnRead, for: .validMock, events: .read)
        _ = waiting.appendContinuation(cnRead1, for: .validMock, events: .read)
        _ = waiting.appendContinuation(cnWrite, for: .validMock, events: .write)

        XCTAssertEqual(
            Set(waiting.continuations(for: .validMock, events: .read)),
            [cnRead1, cnRead]
        )
        XCTAssertEqual(
            Set(waiting.continuations(for: .validMock, events: .write)),
            [cnWrite]
        )
        XCTAssertEqual(
            Set(waiting.continuations(for: .validMock, events: .connection)),
            [cnRead1, cnRead, cnWrite]
        )
        XCTAssertEqual(
            Set(waiting.continuations(for: .validMock, events: [])),
            []
        )
        XCTAssertEqual(
            Set(waiting.continuations(for: .invalid, events: .connection)),
            []
        )
    }
}

private extension EventQueueSocketPool where Queue == MockEventQueue  {
    static func make() -> Self {
        .init(queue: MockEventQueue())
    }
}

final class MockEventQueue: EventQueue {

    private var isWaiting: Bool = false
    private let semaphore = DispatchSemaphore(value: 0)
    private var result: Result<[EventNotification], Error>?

    private(set) var state: State?

    enum State {
        case prepared
        case reset
    }

    func sendResult(returning success: [EventNotification]) {
        result = .success(success)
        if isWaiting {
            semaphore.signal()
        }
    }

    func sendResult(throwing error: Error) {
        result = .failure(error)
        if isWaiting {
            semaphore.signal()
        }
    }

    func addEvents(_ events: Socket.Events, for socket: Socket.FileDescriptor) throws {

    }

    func removeEvents(_ events: Socket.Events, for socket: Socket.FileDescriptor) throws {

    }

    func prepare() throws {
        state = .prepared
    }

    func reset() throws {
        state = .reset
        result = .failure(CancellationError())
        if isWaiting {
            semaphore.signal()
        }
    }

    func getNotifications() throws -> [EventNotification] {
        defer {
            result = nil
        }
        if let result = result {
            return try result.get()
        } else {
            isWaiting = true
            semaphore.wait()
            return try result!.get()
        }
    }
}
