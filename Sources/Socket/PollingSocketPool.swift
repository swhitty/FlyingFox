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

final actor PollingSocketPool: AsyncSocketPool {

    enum Interval {
        case immediate
        case seconds(TimeInterval)

        static let `default` = Interval.seconds(0.1)
    }

    init(interval: Interval = .default) {
        self.interval = interval
    }

    func suspendUntilReady(for events: Socket.Events, on socket: Socket) async throws {
        let socket = SuspendedSocket(file: socket.file, events: events)
        return try await withCancellingContinuation(returning: Void.self) { continuation, handler in
            let continuation = Continuation(continuation)
            appendContinuation(continuation, for: socket)
            handler.onCancel {
                self.removeContinuation(continuation, for: socket)
            }
        }
    }

    private let interval: Interval
    private var waiting: [SuspendedSocket: Set<Continuation>] = [:]

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

    func run() async throws {
        guard state != .running else { throw Error("Not Ready") }
        state = .running

        defer {
            for continuation in waiting.values.flatMap({ $0 }) {
                continuation.cancel()
            }
            waiting = [:]
            state = .complete
        }

        try await poll()
    }

    private func poll() async throws {
        repeat {
            try Task.checkCancellation()
            var buffer = waiting.keys.map {
                pollfd(fd: $0.file, events: Int16($0.events.rawValue), revents: 0)
            }

            if Socket.poll(&buffer, nfds_t(buffer.count), interval.milliseconds) > 0 {
                processPoll(buffer)
            }
            await Task.yield()
        } while true
    }

    private func processPoll(_ buffer: [pollfd]) {
        for file in buffer {
            let events = Socket.Events(rawValue: Int32(file.events))
            let revents = Socket.Events(rawValue: Int32(file.revents))

            if !revents.intersection([.disconnected, .error, .invalid]).isEmpty {
                let socket = SuspendedSocket(file: file.fd, events: events)
                let continuations = waiting[socket]
                waiting[socket] = nil
                continuations?.forEach {
                    $0.disconnected()
                }
            } else if !revents.intersection(events).isEmpty {
                let socket = SuspendedSocket(file: file.fd, events: events)
                let continuations = waiting[socket]
                waiting[socket] = nil
                continuations?.forEach {
                    $0.resume()
                }
            }
        }
    }

    private struct SuspendedSocket: Hashable {
        var file: Int32
        var events: Socket.Events
    }

    final class Continuation: Hashable {

        private let continuation: CheckedContinuation<Void, Swift.Error>

        init(_ continuation: CheckedContinuation<Void, Swift.Error>) {
            self.continuation = continuation
        }

        func resume() {
            continuation.resume()
        }

        func disconnected() {
            continuation.resume(throwing: SocketError.disconnected)
        }

        func cancel() {
            continuation.resume(throwing: CancellationError())
        }

        func hash(into hasher: inout Hasher) {
            ObjectIdentifier(self).hash(into: &hasher)
        }

        static func == (lhs: Continuation, rhs: Continuation) -> Bool {
            lhs === rhs
        }
    }
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
