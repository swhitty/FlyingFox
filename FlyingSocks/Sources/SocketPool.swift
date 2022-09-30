//
//  EventQueueSocketPool.swift
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

import Dispatch
import Foundation

public protocol EventQueue {
    mutating func open() throws
    mutating func close() throws

    mutating func addEvents(_ events: Socket.Events, for socket: Socket.FileDescriptor) throws
    mutating func removeEvents(_ events: Socket.Events, for socket: Socket.FileDescriptor) throws
    func getNotifications() throws -> [EventNotification]
}

public struct EventNotification: Equatable {
    public var file: Socket.FileDescriptor
    public var events: Socket.Events
    public var errors: Set<Error>

    public enum Error {
        case endOfFile
        case error
    }
}

@available(*, unavailable, message: "use .make(maxEvents:)")
public func makeEventQueuePool(maxEvents limit: Int = 20) -> AsyncSocketPool {
    fatalError("init pool directly")
}

#if compiler(>=5.7)
public extension AsyncSocketPool where Self == SocketPool<Poll> {

    static func make(maxEvents limit: Int = 20, logger: Logging? = nil) -> SocketPool<some EventQueue> {
    #if canImport(Darwin)
        return .kQueue(maxEvents: limit, logger: logger)
    #elseif canImport(CSystemLinux)
        return .ePoll(maxEvents: limit, logger: logger)
    #else
        return .poll(interval: .seconds(0.01), logger: logger)
    #endif
    }
}
#endif

public final actor SocketPool<Queue: EventQueue>: AsyncSocketPool {

    private(set) var queue: Queue
    private let dispatchQueue: DispatchQueue
    private(set) var state: State?
    private let logger: Logging?

    public init(queue: Queue, dispatchQueue: DispatchQueue = .init(label: "flyingfox"), logger: Logging? = nil) {
        self.queue = queue
        self.dispatchQueue = dispatchQueue
        self.logger = logger
    }

    public func prepare() async throws {
        logger?.logInfo("SocketPoll prepare")
        try queue.open()
        state = .ready
    }

    public func run() async throws {
        guard state == .ready else { throw Error("Not Ready") }
        state = .running
        defer { cancellAll() }

        repeat {
            if waiting.isEmpty {
                try await suspendUntilContinuationsExist()
            }
            try await processNotifications(getNotifications())
        } while true
    }

    public func suspendSocket(_ socket: Socket, untilReadyFor events: Socket.Events) async throws {
        guard state == .running || state == .ready else { throw Error("Not Ready") }
        let continuation = Continuation()
        defer { removeContinuation(continuation, for: socket.file) }
        try appendContinuation(continuation, for: socket.file, events: events)
        return try await continuation.value
    }

    private func getNotifications() async throws -> [EventNotification] {
        let continuation = CancellingContinuation<[EventNotification], Swift.Error>()
        dispatchQueue.async { [queue] in
            let result = Result {
                try queue.getNotifications()
            }
            continuation.resume(with: result)
        }
        return try await continuation.value
    }

    private func processNotifications(_ notifications: [EventNotification]) {
        for notification in notifications {
            processNotification(notification)
        }
    }

    private func processNotification(_ notification: EventNotification) {
        let continuations = waiting.continuations(
            for: notification.file,
            events: notification.events
        )

        if notification.errors.isEmpty {
            for c in continuations {
                c.resume()
            }
        } else {
            for c in continuations {
                c.resume(throwing: .disconnected)
            }
        }
    }

    enum State {
        case ready
        case running
        case complete
    }

    private func cancellAll() {
        logger?.logInfo("SocketPoll cancellAll")
        try? queue.close()
        state = .complete
        waiting.cancellAll()
        waiting = Waiting()
        loop?.cancel()
        loop = nil
    }

    typealias Continuation = CancellingContinuation<Void, SocketError>
    private var loop: CancellingContinuation<Void, Never>?
    private var waiting = Waiting() {
        didSet {
            if !waiting.isEmpty, let continuation = loop {
                continuation.resume()
            }
        }
    }

    private func suspendUntilContinuationsExist() async throws {
        let continuation = CancellingContinuation<Void, Never>()
        loop = continuation
        defer { loop = nil }
        return try await continuation.value
    }

    private func appendContinuation(_ continuation: Continuation,
                                    for socket: Socket.FileDescriptor,
                                    events: Socket.Events) throws {
        let events = waiting.appendContinuation(continuation,
                                                for: socket,
                                                events: events)
        try queue.addEvents(events, for: socket)
    }

    private func removeContinuation(_ continuation: Continuation,
                                    for socket: Socket.FileDescriptor) {
        let events = waiting.removeContinuation(continuation, for: socket)
        try? queue.removeEvents(events, for: socket)
    }

    private struct Error: LocalizedError {
        var errorDescription: String?

        init(_ description: String) {
            self.errorDescription = description
        }
    }

    struct Waiting {
        private var storage: [Socket.FileDescriptor: [Continuation: Socket.Events]] = [:]

        var isEmpty: Bool { storage.isEmpty }

        // Adds continuation returning all events required by all waiters
        mutating func appendContinuation(_ continuation: Continuation,
                                         for socket: Socket.FileDescriptor,
                                         events: Socket.Events) -> Socket.Events {
            var entries = storage[socket] ?? [:]
            entries[continuation] = events
            storage[socket] = entries
            return entries.values.reduce(Socket.Events()) {
                $0.union($1)
            }
        }

        // Removes continuation returning any events that are no longer being waited
        mutating func removeContinuation(_ continuation: Continuation,
                                         for socket: Socket.FileDescriptor) -> Socket.Events {
            var entries = storage[socket] ?? [:]
            guard let events = entries[continuation] else { return [] }
            entries[continuation] = nil
            storage[socket] = entries.isEmpty ? nil : entries
            let remaining = entries.values.reduce(Socket.Events()) {
                $0.union($1)
            }
            return events.filter { !remaining.contains($0) }
        }

        func continuations(for socket: Socket.FileDescriptor, events: Socket.Events) -> [Continuation] {
            let entries = storage[socket] ?? [:]
            return entries.compactMap { c, ev in
                if events.intersection(ev).isEmpty {
                    return nil
                } else {
                    return c
                }
            }
        }

        func cancellAll() {
            for continuation in storage.values.flatMap(\.keys) {
                continuation.cancel()
            }
        }
    }
}
