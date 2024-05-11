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
    mutating func stop() throws
    mutating func close() throws

    mutating func addEvents(_ events: Socket.Events, for socket: Socket.FileDescriptor) throws
    mutating func removeEvents(_ events: Socket.Events, for socket: Socket.FileDescriptor) throws
    func getNotifications() throws -> [EventNotification]
}

public struct EventNotification: Equatable, Sendable {
    public var file: Socket.FileDescriptor
    public var events: Socket.Events
    public var errors: Set<Error>

    public enum Error: Sendable {
        case endOfFile
        case error
    }
}

@available(*, unavailable, message: "use .make(maxEvents:)")
public func makeEventQueuePool(maxEvents limit: Int = 20) -> any AsyncSocketPool {
    fatalError("init pool directly")
}

public extension AsyncSocketPool where Self == SocketPool<Poll> {

    static func make(maxEvents limit: Int = 20, logger: some Logging = .disabled) -> some AsyncSocketPool {
    #if canImport(Darwin)
        return .kQueue(maxEvents: limit, logger: logger)
    #elseif canImport(CSystemLinux)
        return .ePoll(maxEvents: limit, logger: logger)
    #else
        return .poll(interval: .seconds(0.01), logger: logger)
    #endif
    }
}

public final actor SocketPool<Queue: EventQueue>: AsyncSocketPool {

    private(set) var queue: Queue
    private let dispatchQueue: DispatchQueue
    private(set) var state: State?
    private let logger: any Logging

    public init(queue: Queue, dispatchQueue: DispatchQueue = .init(label: "flyingfox"), logger: some Logging = .disabled) {
        self.queue = queue
        self.dispatchQueue = dispatchQueue
        self.logger = logger
    }

    public func prepare() async throws {
        logger.logInfo("SocketPoll prepare")
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
        return try await withIdentifiableThrowingContinuation(isolation: self) {
            appendContinuation($0, for: socket.file, events: events)
        } onCancel: { id in
            Task {
                await self.resumeContinuation(id: id, with: .failure(CancellationError()), for: socket.file)
            }
        }
    }

    private func getNotifications() async throws -> [EventNotification] {
        try Task.checkCancellation()
        return try await withIdentifiableThrowingContinuation(isolation: self) { continuation in
            dispatchQueue.async { [queue] in
                let result = Result {
                    try queue.getNotifications()
                }
                continuation.resume(with: result)
            }
        } onCancel: { _ in
            Task { await self.stopQueue() }
        }
    }

    private func stopQueue() {
        try? queue.stop()
    }

    private func processNotifications(_ notifications: [EventNotification]) {
        for notification in notifications {
            processNotification(notification)
        }
    }

    private func processNotification(_ notification: EventNotification) {
        for id in waiting.continuationIDs(for: notification.file, events: notification.events) {
            resumeContinuation(id: id, with: notification.result, for: notification.file)
        }
    }

    enum State {
        case ready
        case running
        case complete
    }

    private func cancellAll() {
        logger.logInfo("SocketPoll cancellAll")
        try? queue.stop()
        state = .complete
        waiting.cancellAll()
        waiting = Waiting()
        if let loop {
            self.loop = nil
            loop.resume(throwing: CancellationError())
        }
        try? queue.close()
    }

    typealias Continuation = IdentifiableContinuation<Void, any Swift.Error>
    private var loop: Continuation?
    private var waiting = Waiting() {
        didSet {
            if let loop, !waiting.isEmpty {
                self.loop = nil
                loop.resume()
            }
        }
    }

    private func suspendUntilContinuationsExist() async throws {
        try await withIdentifiableThrowingContinuation(isolation: self) {
            loop = $0
        } onCancel: { id in
            Task { await self.cancelLoopContinuation(with: id) }
        }
    }

    private func cancelLoopContinuation(with id: Continuation.ID) {
        if let loop, loop.id == id {
            self.loop = nil
            loop.resume(throwing: CancellationError())
        }
    }

    private func appendContinuation(
        _ continuation: Continuation,
        for socket: Socket.FileDescriptor,
        events: Socket.Events
    ) {
        let events = waiting.appendContinuation(continuation, for: socket, events: events)
        do  {
            try queue.addEvents(events, for: socket)
        } catch {
            resumeContinuation(
                id: continuation.id,
                with: .failure(error),
                for: socket
            )
        }
    }

    private func resumeContinuation(
        id: Continuation.ID,
        with result: Result<Void, any Swift.Error>,
        for socket: Socket.FileDescriptor
    ) {
        do {
            let events = waiting.resumeContinuation(id: id, with: result, for: socket)
            try queue.removeEvents(events, for: socket)
        } catch {
            logger.logError("resumeContinuation queue.removeEvents: \(error.localizedDescription)")
        }
    }

    private struct Error: LocalizedError {
        var errorDescription: String?

        init(_ description: String) {
            self.errorDescription = description
        }
    }

    struct Waiting {
        private var storage: [Socket.FileDescriptor: [Continuation.ID: (continuation: Continuation, events: Socket.Events)]] = [:]

        var isEmpty: Bool { storage.isEmpty }

        // Adds continuation returning all events required by all waiters
        mutating func appendContinuation(_ continuation: Continuation,
                                         for socket: Socket.FileDescriptor,
                                         events: Socket.Events) -> Socket.Events {
            var entries = storage[socket] ?? [:]
            entries[continuation.id] = (continuation, events)
            storage[socket] = entries
            return entries.values.reduce(Socket.Events()) {
                $0.union($1.events)
            }
        }

        // Resumes and removes continuation, returning any events that are no longer being waited
        mutating func resumeContinuation(id: Continuation.ID,
                                         with result: Result<Void, any Swift.Error>,
                                         for socket: Socket.FileDescriptor) -> Socket.Events {
            var entries = storage[socket] ?? [:]
            guard let (continuation, events) = entries.removeValue(forKey: id) else { return [] }
            continuation.resume(with: result)
            storage[socket] = entries.isEmpty ? nil : entries
            let remaining = entries.values.reduce(Socket.Events()) {
                $0.union($1.events)
            }
            return events.filter { !remaining.contains($0) }
        }

        func continuationIDs(for socket: Socket.FileDescriptor, events: Socket.Events) -> [Continuation.ID] {
            let entries = storage[socket] ?? [:]
            return entries.compactMap { id, ev in
                if events.intersection(ev.events).isEmpty {
                    return nil
                } else {
                    return id
                }
            }
        }

        mutating func cancellAll() {
            let continuations = storage.values.flatMap(\.values).map(\.continuation)
            storage = [:]
            for continuation in continuations {
                continuation.resume(throwing: CancellationError())
            }
        }
    }
}

private extension EventNotification {
    var result: Result<Void, any Swift.Error> {
        errors.isEmpty ? .success(()) : .failure(SocketError.disconnected)
    }
}
