//
//  SocketPoolTests.swift
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
import Foundation
import Testing

struct SocketPoolTests {

    typealias Continuation = IdentifiableContinuation<Void, any Swift.Error>
    typealias Waiting = SocketPool<MockEventQueue>.Waiting

#if canImport(Darwin)
    @Test
    func kqueuePool() {
        let pool = SocketPool.make(maxEvents: 5)
        #expect(type(of: pool) == SocketPool<kQueue>.self)
    }
#endif

#if canImport(CSystemLinux)
    @Test
    func ePollPool() {
        let pool = SocketPool.make(maxEvents: 5)
        #expect(type(of: pool) == SocketPool<ePoll>.self)
    }
#endif

    @Test
    func poll() {
        let pool: some AsyncSocketPool = .poll()
        #expect(type(of: pool) == SocketPool<Poll>.self)
    }

    @Test
    func queuePrepare() async throws {
        let pool = SocketPool.make()

        #expect(await pool.state == nil)

        try await pool.prepare()
        #expect(await pool.state == .ready)
    }

    @Test
    func queueRun_ThrowsError_WhenNotReady() async throws {
        let pool = SocketPool.make()

        await #expect(throws: (any Error).self) {
            try await pool.run()
        }
    }

    @Test
    func suspendedSockets_ThrowError_WhenCancelled() async throws {
        let pool = SocketPool.make()
        try await pool.prepare()

        let task = Task {
            let socket = try Socket(domain: AF_UNIX, type: Socket.stream)
            try await pool.suspendSocket(socket, untilReadyFor: .read)
        }

        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test
    func cancellingPollingPool_CancelsSuspendedSocket() async throws {
        let pool = SocketPool.make()
        try await pool.prepare()

        _ = Task(timeout: 0.2) {
            try await pool.run()
        }

        let (s1, s2) = try Socket.makeNonBlockingPair()
        await #expect(throws: CancellationError.self) {
            try await pool.suspendSocket(s1, untilReadyFor: .read)
        }

        try s1.close()
        try s2.close()
    }

    @Test
    func cancellingPool_CancelsNewSockets() async throws {
        let pool = SocketPool.make()
        try await pool.prepare()

        let task = Task(timeout: 0.1) {
            try await pool.run()
        }

        try? await task.value

        let socket = try Socket(domain: AF_UNIX, type: Socket.stream)
        await #expect(throws: (any Error).self) {
            try await pool.suspendSocket(socket, untilReadyFor: .read)
        }
    }

    @Test
    func queueNotification_ResumesSocket() async throws {
        let pool = SocketPool.make()
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

        await #expect(throws: Never.self) {
            try await pool.suspendSocket(socket, untilReadyFor: .read)
        }
    }

    @Test
    func queueNotificationError_ResumesSocket_WithError() async throws {
        let pool = SocketPool.make()
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

        await #expect(throws: SocketError.disconnected) {
            try await pool.suspendSocket(socket, untilReadyFor: .read)
        }
    }

    @Test
    func waiting_IsEmpty() async {
        let cn = await Continuation.make()

        var waiting = Waiting()
        #expect(waiting.isEmpty)

        _ = waiting.appendContinuation(cn, for: .validMock, events: .read)
        #expect(waiting.isEmpty == false)

        _ = waiting.resumeContinuation(id: cn.id, with: .success(()), for: .validMock)
        #expect(waiting.isEmpty)
    }

    @Test
    func waitingEvents() async {
        var waiting = Waiting()
        let cnRead = await Continuation.make()
        let cnRead1 = await Continuation.make()
        let cnWrite = await Continuation.make()

        #expect(
            waiting.appendContinuation(cnRead, for: .validMock, events: .read) == [.read]
        )
        #expect(
            waiting.appendContinuation(cnRead1, for: .validMock, events: .read) == [.read]
        )
        #expect(
            waiting.appendContinuation(cnWrite, for: .validMock, events: .write) == [.read, .write]
        )
        #expect(
            waiting.resumeContinuation(id: .init(), with: .success(()), for: .validMock) == []
        )
        #expect(
            waiting.resumeContinuation(id: cnWrite.id, with: .success(()), for: .validMock) == [.write]
        )
        #expect(
            waiting.resumeContinuation(id: cnRead.id, with: .success(()), for: .validMock) == []
        )
        #expect(
            waiting.resumeContinuation(id: cnRead1.id, with: .success(()), for: .validMock) == [.read]
        )
    }

    @Test
    func waitingContinuations() async {
        var waiting = Waiting()
        let cnRead = await Continuation.make()
        let cnRead1 = await Continuation.make()
        let cnWrite = await Continuation.make()
        defer {
            cnRead.resume()
            cnRead1.resume()
            cnWrite.resume()
        }

        _ = waiting.appendContinuation(cnRead, for: .validMock, events: .read)
        _ = waiting.appendContinuation(cnRead1, for: .validMock, events: .read)
        _ = waiting.appendContinuation(cnWrite, for: .validMock, events: .write)

        #expect(
            Set(waiting.continuationIDs(for: .validMock, events: .read)) == [cnRead1.id, cnRead.id]
        )
        #expect(
            Set(waiting.continuationIDs(for: .validMock, events: .write)) == [cnWrite.id]
        )
        #expect(
            Set(waiting.continuationIDs(for: .validMock, events: .connection)) == [cnRead1.id, cnRead.id, cnWrite.id]
        )
        #expect(
            Set(waiting.continuationIDs(for: .validMock, events: [])) == []
        )
        #expect(
            Set(waiting.continuationIDs(for: .invalid, events: .connection)) == []
        )
    }
}

private extension SocketPool where Queue == MockEventQueue  {
    static func make() -> Self {
        .init(queue: MockEventQueue())
    }
}

final class MockEventQueue: EventQueue, @unchecked Sendable {

    private var isWaiting: Bool = false
    private let semaphore = DispatchSemaphore(value: 0)
    private var result: Result<[EventNotification], any Error>?

    private(set) var state: State?

    enum State {
        case open
        case stopped
        case closed
    }

    func sendResult(returning success: [EventNotification]) {
        result = .success(success)
        if isWaiting {
            semaphore.signal()
        }
    }

    func sendResult(throwing error: some Error) {
        result = .failure(error)
        if isWaiting {
            semaphore.signal()
        }
    }

    func addEvents(_ events: Socket.Events, for socket: Socket.FileDescriptor) throws {

    }

    func removeEvents(_ events: Socket.Events, for socket: Socket.FileDescriptor) throws {

    }

    func open() throws {
        guard (state == nil || state == .closed) else { throw InvalidStateError() }
        state = .open
    }

    func stop() throws {
        guard state == .open else { throw InvalidStateError() }
        state = .stopped
        result = .failure(CancellationError())
        if isWaiting {
            semaphore.signal()
        }
    }

    func close() throws {
        guard state == .stopped else { throw InvalidStateError() }
        state = .closed
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

    private struct InvalidStateError: Error { }
}


extension IdentifiableContinuation where T: Sendable {
    static func make() async -> IdentifiableContinuation<T, any Error> {
        await Host().makeThrowingContinuation()
    }

    private actor Host {
        func makeThrowingContinuation() async -> IdentifiableContinuation<T, any Error> {
            await withCheckedContinuation { outer in
                Task {
                    try? await withIdentifiableThrowingContinuation(isolation: self) {
                        outer.resume(returning: $0)
                    } onCancel: { _ in }
                }
            }
        }
    }
}

extension Socket.FileDescriptor {
    static let validMock = Socket.FileDescriptor(rawValue: 999)
}
