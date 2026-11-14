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
            let socket = try Socket(domain: AF_UNIX, type: .stream)
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

        let socket = try Socket(domain: AF_UNIX, type: .stream)
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

        let socket = try Socket(domain: AF_UNIX, type: .stream)
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

        let socket = try Socket(domain: AF_UNIX, type: .stream)
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
    func run_ThrowsCancellationError_WhenCancelledWhileWaiting() async throws {
        let pool = SocketPool.make()
        try await pool.prepare()
        let task = Task { try await pool.run() }

        let socket = try Socket(domain: AF_UNIX, type: .stream)
        defer { try? socket.close() }
        let suspension = Task {
            try await pool.suspendSocket(socket, untilReadyFor: .read)
        }
        defer { suspension.cancel() }

        try await pool.queue.waitUntilWaiting()
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test
    func removeSocket_ResumesSuspendedSocket_WithDisconnected() async throws {
        let pool = SocketPool.make()
        try await pool.prepare()
        let task = Task { try await pool.run() }
        defer { task.cancel() }

        let socket = try Socket(domain: AF_UNIX, type: .stream)
        let suspension = Task {
            try await pool.suspendSocket(socket, untilReadyFor: .read)
        }
        try await Task.sleep(seconds: 0.1)

        await pool.removeSocket(socket)

        await #expect(throws: SocketError.disconnected) {
            try await suspension.value
        }
    }

#if canImport(Darwin) || canImport(CSystemLinux)
    @Test
    func pool_CanBeStoppedAndRestarted_Repeatedly() async throws {
        // stop() leaves the queue's wake triggered, so each restart must reset it
        let pool = SocketPool.make(maxEvents: 4)
        let (socket, peer) = try Socket.makeNonBlockingPair()
        defer {
            try? socket.close()
            try? peer.close()
        }

        for _ in 0..<100 {
            try await pool.prepare()
            let run = Task { try await pool.run() }
            let suspended = Task { try await pool.suspendSocket(socket, untilReadyFor: .read) }
            await Task.yield()
            run.cancel()

            #expect(await run.completes(within: 2))
            #expect(await suspended.completes(within: 2))
        }
    }

    @Test
    func removeSocket_WakesSuspendedSocket_BeforeItIsClosed() async throws {
        let pool = SocketPool.make(maxEvents: 4)
        try await pool.prepare()
        let run = Task { try await pool.run() }
        defer { run.cancel() }

        let (socket, peer) = try Socket.makeNonBlockingPair()
        defer { try? peer.close() }
        let suspended = Task(timeout: 1) { try await pool.suspendSocket(socket, untilReadyFor: .read) }
        try await Task.sleep(seconds: 0.1)

        // closing the socket would silently drop it from the queue leaving the suspension
        // waiting forever, so the pool must wake it before the socket is closed
        await pool.removeSocket(socket)
        try socket.close()

        await #expect(throws: SocketError.disconnected) {
            try await suspended.value
        }
    }

    @Test
    func reusedDescriptor_IsWoken_AfterTheSuspendedSocketIsReplacedAndCancelled() async throws {
        let pool = SocketPool.make(maxEvents: 4)
        try await pool.prepare()
        let run = Task { try await pool.run() }
        defer { run.cancel() }

        let (old, oldPeer) = try Socket.makeNonBlockingPair()
        defer { try? oldPeer.close() }
        let suspended = Task { try await pool.suspendSocket(old, untilReadyFor: .read) }
        try await Task.sleep(seconds: 0.1)

        // closing the socket drops it from the queue; cancelling its suspension then fails
        // to remove it, and a socket given the same descriptor must still be woken
        let (reused, peer) = try Socket.makeNonBlockingPair(replacing: old)
        defer {
            try? reused.close()
            try? peer.close()
        }
        suspended.cancel()
        _ = try? await suspended.value

        _ = try peer.write(Data([1]))
        let woken = Task(timeout: 1) { try await pool.suspendSocket(reused, untilReadyFor: .read) }
        await #expect(throws: Never.self) {
            try await woken.value
        }
    }

    @Test
    func reusedDescriptor_IsWoken_WhileTheReplacedSocketIsStillSuspended() async throws {
        let pool = SocketPool.make(maxEvents: 4)
        try await pool.prepare()
        let run = Task { try await pool.run() }
        defer { run.cancel() }

        let (old, oldPeer) = try Socket.makeNonBlockingPair()
        defer { try? oldPeer.close() }
        let suspended = Task { try await pool.suspendSocket(old, untilReadyFor: .read) }
        defer { suspended.cancel() }
        try await Task.sleep(seconds: 0.1)

        // the socket is closed and its descriptor given to another before its suspension
        // ends; the new socket's own suspension must still register with the queue
        let (reused, peer) = try Socket.makeNonBlockingPair(replacing: old)
        defer {
            try? reused.close()
            try? peer.close()
        }

        _ = try peer.write(Data([1]))
        let woken = Task(timeout: 1) { try await pool.suspendSocket(reused, untilReadyFor: .read) }
        await #expect(throws: Never.self) {
            try await woken.value
        }
    }
#endif

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
            Set(waiting.continuationIDs(for: .validMock, events: [.read, .write])) == [cnRead1.id, cnRead.id, cnWrite.id]
        )
        #expect(
            Set(waiting.continuationIDs(for: .validMock, events: [])) == []
        )
        #expect(
            Set(waiting.continuationIDs(for: .invalid, events: .connection)) == []
        )
    }
}

#if canImport(Darwin) || canImport(CSystemLinux)
private extension Socket {
    /// A connected pair whose first socket takes over `socket`'s descriptor, closing it, as
    /// a new socket can be given the descriptor of one just closed. `dup2` closes and
    /// replaces in one step, so no other socket can be given the descriptor in between.
    static func makeNonBlockingPair(replacing socket: Socket) throws -> (Socket, Socket) {
        let (first, second) = try Socket.makeNonBlockingPair()
        guard dup2(first.file.rawValue, socket.file.rawValue) != -1 else {
            throw SocketError.makeFailed("dup2")
        }
        try first.close()
        return (Socket(file: socket.file), second)
    }
}
#endif

private extension Task where Failure == any Error {

    /// Whether the task completes within the timeout. Unlike `withThrowingTimeout`, this returns
    /// on timeout without waiting for the task, so a task that never completes fails the test
    /// instead of hanging it.
    func completes(within seconds: TimeInterval) async -> Bool {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let waiter = Task<Void, Never> {
            _ = await result
            continuation.yield(true)
        }
        let timer = Task<Void, Never> {
            try? await Task<Never, Never>.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            continuation.yield(false)
        }
        var iterator = stream.makeAsyncIterator()
        let completed = await iterator.next() ?? false
        continuation.finish()
        timer.cancel()
        _ = waiter
        return completed
    }
}

private extension SocketPool where Queue == MockEventQueue  {
    static func make() -> Self {
        .init(queue: MockEventQueue())
    }
}

final class MockEventQueue: EventQueue, Sendable {

    private let storage = Mutex(Storage())
    private let semaphore = DispatchSemaphore(value: 0)

    private struct Storage {
        var state: State?
        var isWaiting = false
        var result: Result<[EventNotification], any Error>?
    }

    var state: State? {
        storage.withLock { $0.state }
    }

    enum State {
        case open
        case stopped
        case closed
    }

    func sendResult(returning success: [EventNotification]) {
        deliver(.success(success))
    }

    func sendResult(throwing error: some Error) {
        deliver(.failure(error))
    }

    /// Suspends until `getNotifications()` is blocked waiting for a result.
    func waitUntilWaiting(timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !storage.withLock({ $0.isWaiting }) {
            guard Date() < deadline else { throw TimeoutError() }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    func addEvents(_ events: Socket.Events, for socket: Socket.FileDescriptor) throws {

    }

    func removeEvents(_ events: Socket.Events, for socket: Socket.FileDescriptor) throws {

    }

    func open() throws {
        try storage.withLock {
            guard ($0.state == nil || $0.state == .closed) else { throw InvalidStateError() }
            $0.state = .open
        }
    }

    func stop() throws {
        try storage.withLock {
            guard $0.state == .open else { throw InvalidStateError() }
            $0.state = .stopped
        }
        // as kQueue and ePoll fail a stopped wait
        deliver(.failure(SocketError.disconnected))
    }

    func close() throws {
        try storage.withLock {
            guard $0.state == .stopped else { throw InvalidStateError() }
            $0.state = .closed
        }
    }

    func getNotifications() throws -> [EventNotification] {
        let mustWait = storage.withLock {
            guard $0.result == nil else { return false }
            $0.isWaiting = true
            return true
        }
        if mustWait {
            semaphore.wait()
        }
        let result = storage.withLock {
            defer { $0.result = nil }
            return $0.result!
        }
        return try result.get()
    }

    // Stores the result, waking getNotifications() if it is blocked. Clearing isWaiting
    // here means a waiter is only ever signalled once.
    private func deliver(_ result: Result<[EventNotification], any Error>) {
        let shouldSignal = storage.withLock {
            $0.result = result
            guard $0.isWaiting else { return false }
            $0.isWaiting = false
            return true
        }
        if shouldSignal {
            semaphore.signal()
        }
    }

    private struct InvalidStateError: Error { }
    private struct TimeoutError: Error { }
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
