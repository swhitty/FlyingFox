//
//  HTTPResponse+SSE.swift
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

import FlyingSocks
import Foundation

public extension HTTPResponse {

    /// A `text/event-stream` response that sends each event to the client as it is produced.
    ///
    /// The events are read once the handler has returned, so the server's handler timeout does
    /// not apply to them. The stream ends when the sequence ends, and the sequence is cancelled
    /// when the client disconnects or the server stops.
    ///
    /// - Parameters:
    ///   - headers: Additional headers. `Content-Type` and `Cache-Control` are set unless provided.
    ///   - events: The events to send. Throwing ends the response without completing it, so the
    ///     client reconnects.
    ///   - heartbeat: Seconds between empty comments that keep an idle connection open and detect
    ///     a disconnected client, or nil for none. Must be greater than zero.
    ///   - capacity: Events encoded and waiting to be written. The sequence is not read while
    ///     this many wait for a slow client.
    init<Events: AsyncSequence & Sendable>(
        headers: HTTPHeaders = [:],
        serverSentEvents events: Events,
        heartbeat: TimeInterval? = 15,
        capacity: Int = 16
    ) where Events.Element == SSEEvent {
        precondition(heartbeat.map { $0 > 0 } ?? true, "heartbeat must be greater than zero")
        precondition(capacity >= 0, "capacity must not be negative")
        var headers = headers
        // HTML §9.2.2: clients accept only text/event-stream, which §9.2.5 defines as UTF-8.
        if headers[.contentType] == nil {
            headers[.contentType] = "text/event-stream"
        }
        if headers[.cacheControl] == nil {
            headers[.cacheControl] = "no-cache"
        }
        let bytes = SSEEventBytes(events: events, heartbeat: heartbeat, capacity: capacity)
        // RFC 9112 §7.1: without a Content-Length the body is sent chunked, one chunk per event.
        self.init(statusCode: .ok, headers: headers, body: HTTPBodySequence(from: bytes))
    }
}

public extension HTTPRequest {

    /// The `Last-Event-ID` header a client sends when it reconnects to an event stream (HTML §9.2.4).
    var lastEventID: String? {
        headers[.lastEventID]
    }
}

public extension HTTPHeader {
    static let lastEventID = HTTPHeader("Last-Event-ID")
}

/// The encoded bytes of an event stream, produced by a task that reads the events and sends
/// heartbeats into a bounded handoff. Each buffer holds at most one event.
struct SSEEventBytes<Events: AsyncSequence & Sendable>: AsyncBufferedSequence, Sendable where Events.Element == SSEEvent {
    typealias Element = UInt8

    let events: Events
    let heartbeat: TimeInterval?
    let capacity: Int

    func makeAsyncIterator() -> Iterator {
        Iterator(producer: Producer(events: events, heartbeat: heartbeat, capacity: capacity))
    }

    struct Iterator: AsyncBufferedIteratorProtocol {
        private let producer: Producer
        private var pending: ArraySlice<UInt8> = []

        init(producer: Producer) {
            self.producer = producer
        }

        mutating func next() async throws -> UInt8? {
            try await nextBuffer(suggested: 1)?.first
        }

        mutating func nextBuffer(suggested count: Int) async throws -> ArraySlice<UInt8>? {
            if pending.isEmpty {
                guard let event = try await producer.handoff.next() else { return nil }
                pending = event[...]
            }
            let buffer = pending.prefix(Swift.max(count, 1))
            pending = pending.dropFirst(buffer.count)
            return buffer
        }
    }

    /// Owns the task producing the events; it is cancelled once the iterator is released,
    /// such as when a write to the client fails.
    final class Producer: Sendable {
        let handoff: AsyncHandoff<[UInt8]>
        private let task: Task<Void, Never>

        init(events: Events, heartbeat: TimeInterval?, capacity: Int) {
            let handoff = AsyncHandoff<[UInt8]>(capacity: capacity)
            self.handoff = handoff
            self.task = Task {
                await Self.run(events: events, heartbeat: heartbeat, handoff: handoff)
            }
        }

        deinit {
            task.cancel()
        }

        private static func run(events: Events, heartbeat: TimeInterval?, handoff: AsyncHandoff<[UInt8]>) async {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    do {
                        for try await event in events {
                            try await handoff.send(event.encoded)
                        }
                        await handoff.finish()
                    } catch is CancellationError, is AsyncHandoffFinishedError {
                        await handoff.finish()
                    } catch {
                        await handoff.finish(throwing: error)
                    }
                }
                if let heartbeat {
                    group.addTask {
                        let comment = SSEEvent.comment().encoded
                        // clamped so a huge or infinite interval can't overflow UInt64
                        let seconds = Swift.min(Swift.max(heartbeat, 0.001), 1_000_000_000)
                        let nanoseconds = UInt64(seconds * 1_000_000_000)
                        do {
                            while true {
                                try await Task.sleep(nanoseconds: nanoseconds)
                                try await handoff.send(comment)
                            }
                        } catch { }
                    }
                }
                // the stream ends with the events; cancel the heartbeat
                await group.next()
                group.cancelAll()
            }
        }
    }
}
