//
//  PollingSocketPool.swift
//  FlyingFox
//
//  Created by Simon Whitty on 13/02/2022.
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

import Foundation
#if canImport(WinSDK)
import WinSDK.WinSock2
#endif

public final actor PollingSocketPool: AsyncSocketPool {

    public enum Interval {
        case immediate
        case seconds(TimeInterval)
    }

    public init(pollInterval: Interval, loopInterval: Interval) {
        self.pollInterval = pollInterval
        self.loopInterval = loopInterval
    }

    public func suspendSocket(_ socket: Socket, untilReadyFor events: Socket.Events) async throws {
        let socket = SuspendedSocket(file: socket.file, events: events)
        return try await withCancellingContinuation(returning: Void.self) { continuation, handler in
            let continuation = Continuation(continuation)
            appendContinuation(continuation, for: socket)
            handler.onCancel {
                self.removeContinuation(continuation, for: socket)
            }
        }
    }

    private let pollInterval: Interval
    private let loopInterval: Interval
    private var waiting: [SuspendedSocket: Set<Continuation>] = [:] {
        didSet {
            if !waiting.isEmpty, let continuation = loop {
                loop = nil
                continuation.resume()
            }
        }
    }

    private var loop: Continuation?

    private func suspendLoopUntilSocketsExist() async throws {
        try await withCancellingContinuation(returning: Void.self) { continuation, handler in
            let continuation = Continuation(continuation)
            loop = continuation
            handler.onCancel {
                continuation.cancel()
            }
        }
    }

    private func appendContinuation(_ continuation: Continuation, for socket: SuspendedSocket) {
        guard state != .complete else {
            continuation.cancel()
            return
        }
        var existing = waiting[socket] ?? []
        existing.insert(continuation)
        waiting[socket] = existing
    }

    private func _removeContinuation(_ continuation: Continuation, for socket: SuspendedSocket) {
        guard waiting[socket]?.contains(continuation) == true else { return }
        waiting[socket]?.remove(continuation)
        continuation.cancel()
    }

    // Careful not to escape non-isolated method
    // https://bugs.swift.org/browse/SR-15745
    nonisolated private func removeContinuation(_ continuation: Continuation, for socket: SuspendedSocket) {
        Task { await _removeContinuation(continuation, for: socket) }
    }

    private var state: State = .ready

    private enum State {
        case ready
        case running
        case complete
    }

    public func run() async throws {
        guard state != .running else { throw Error("Not Ready") }
        state = .running

        defer {
            for continuation in waiting.values.flatMap({ $0 }) {
                continuation.cancel()
            }
            waiting = [:]
            state = .complete
            loop = nil
        }

        try await poll()
    }

    private func poll() async throws {
        repeat {
            try Task.checkCancellation()
            let sockets = waiting.keys
            var buffer = sockets.map {
                Socket.pollfd(fd: $0.file.rawValue, events: Int16($0.events.pollEvents.rawValue), revents: 0)
            }
            if Socket.poll(&buffer, UInt32(buffer.count), pollInterval.milliseconds) > 0 {
                for (socket, pollfd) in zip(sockets, buffer) {
                    processPoll(socket: socket, revents: .makeRevents(pollfd.revents, for: socket.events))
                }
            }

            if waiting.isEmpty {
                try await suspendLoopUntilSocketsExist()
            } else {
                switch loopInterval {
                case .immediate:
                    await Task.yield()
                case .seconds(let seconds):
                    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                }
            }
        } while true
    }

    private func processPoll(socket: SuspendedSocket, revents: POLLEvents) {
        if revents.intersects(with: socket.events.pollEvents) {
            let continuations = waiting[socket]
            waiting[socket] = nil
            continuations?.forEach {
                $0.resume()
            }
        } else if revents.intersects(with: .errors) {
            let continuations = waiting[socket]
            waiting[socket] = nil
            continuations?.forEach {
                $0.disconnected()
            }
        }
    }

    private struct SuspendedSocket: Hashable {
        var file: Socket.FileDescriptor
        var events: Socket.Events
    }

    final class Continuation: Hashable, @unchecked Sendable {

        private let continuation: CheckedContinuation<Void, Swift.Error>
        @Locked private(set) var isComplete: Bool

        init(_ continuation: CheckedContinuation<Void, Swift.Error>) {
            self.continuation = continuation
            self.isComplete = false
        }

        func resume() {
            _isComplete.unlock {
                if $0 == false {
                    continuation.resume()
                    $0 = true
                }
            }
        }

        func disconnected() {
            _isComplete.unlock {
                if $0 == false {
                    continuation.resume(throwing: SocketError.disconnected)
                    $0 = true
                }
            }
        }

        func cancel() {
            _isComplete.unlock {
                if $0 == false {
                    continuation.resume(throwing: CancellationError())
                    $0 = true
                }
            }
        }

        func hash(into hasher: inout Hasher) {
            ObjectIdentifier(self).hash(into: &hasher)
        }

        static func == (lhs: Continuation, rhs: Continuation) -> Bool {
            lhs === rhs
        }
    }
}

extension PollingSocketPool {
    static let client: PollingSocketPool = {
        let pool = PollingSocketPool(pollInterval: .immediate, loopInterval: .seconds(0.1))
        Task { try await pool.run() }
        return pool
    }()
}

extension PollingSocketPool.Interval {
    var milliseconds: Int32 {
        switch self {
        case .immediate:
            return 0
        case .seconds(let seconds):
            return Int32(seconds * 1000)
        }
    }
}

extension PollingSocketPool {

    struct Error: LocalizedError {
        var errorDescription: String?

        init(_ description: String) {
            self.errorDescription = description
        }
    }
}

private struct POLLEvents: OptionSet, Hashable {
    var rawValue: Int32

    static let read = POLLEvents(rawValue: POLLIN)
    static let write = POLLEvents(rawValue: POLLOUT)
    static let err = POLLEvents(rawValue: POLLERR)
    static let hup = POLLEvents(rawValue: POLLHUP)
    static let nval = POLLEvents(rawValue: POLLNVAL)

    static let errors: POLLEvents = [.err, .hup, .nval]

    func intersects(with events: POLLEvents) -> Bool {
        !intersection(events).isEmpty
    }

    static func makeRevents(_ revents: Int16, for requested: Socket.Events) -> POLLEvents {
        let events = POLLEvents(rawValue: Int32(revents))
        let errors = events.intersection(.errors)
        if requested == .connection && !errors.isEmpty {
            return errors
        }
        return events
    }
}

private extension Socket.Event {
    var pollEvents: POLLEvents {
        switch self {
        case .read:
            return .read
        case .write:
            return .write
        case .connection:
            return [.read, .write]
        }
    }
}

private extension Socket.Events {
    var pollEvents: POLLEvents {
        reduce(POLLEvents()) { [$0, $1.pollEvents] }
    }
}
