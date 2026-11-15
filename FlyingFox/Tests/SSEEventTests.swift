//
//  SSEEventTests.swift
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

@testable import FlyingFox
@testable import FlyingSocks
import Foundation
import Testing

struct SSEEventTests {

    @Test
    func data_isEncoded() {
        #expect(SSEEvent(data: "hello").string == "data: hello\n\n")
    }

    @Test
    func multiLineData_isSplitAtEachLineBreak() {
        #expect(
            SSEEvent(data: "a\nb\r\nc\rd").string == "data: a\ndata: b\ndata: c\ndata: d\n\n"
        )
        #expect(
            SSEEvent(data: "a\n\nb\n").string == "data: a\ndata: \ndata: b\ndata: \n\n"
        )
    }

    @Test
    func unicodeLineSeparators_areNotLineBreaks() {
        #expect(
            SSEEvent(data: "a\u{2028}b\u{85}c").string == "data: a\u{2028}b\u{85}c\n\n"
        )
    }

    @Test
    func emptyData_isEncoded() {
        #expect(SSEEvent(data: "").string == "data: \n\n")
    }

    @Test
    func leadingSpace_isKept() throws {
        #expect(try SSEEvent(event: " x", data: " y").string == "event:  x\ndata:  y\n\n")
    }

    @Test
    func allFields_areEncoded() throws {
        let event = try SSEEvent(event: "update", data: "{}", id: "42", retry: 3000)
        #expect(event.string == "event: update\nid: 42\nretry: 3000\ndata: {}\n\n")
    }

    @Test
    func eventWithoutData_isEncoded() throws {
        #expect(try SSEEvent(id: "7").string == "id: 7\n\n")
        #expect(try SSEEvent(id: "").string == "id: \n\n")
    }

    @Test
    func comment_isEncoded() {
        #expect(SSEEvent.comment().string == ":\n\n")
        #expect(SSEEvent.comment("hi\nthere").string == ": hi\n: there\n\n")
    }

    @Test
    func invalidFields_throw() {
        #expect(throws: SSEEvent.InvalidField.event) { try SSEEvent(event: "a\nb") }
        #expect(throws: SSEEvent.InvalidField.event) { try SSEEvent(event: "a\rb") }
        #expect(throws: SSEEvent.InvalidField.id) { try SSEEvent(id: "a\r\nb") }
        #expect(throws: SSEEvent.InvalidField.id) { try SSEEvent(id: "a\0b") }
        #expect(throws: SSEEvent.InvalidField.retry) { try SSEEvent(retry: -1) }
    }

    @Test
    func response_hasEventStreamHeaders() {
        let response = HTTPResponse(serverSentEvents: AsyncStream<SSEEvent> { $0.finish() })
        #expect(response.statusCode == .ok)
        #expect(response.headers[.contentType] == "text/event-stream")
        #expect(response.headers[.cacheControl] == "no-cache")
        #expect(HTTPEncoder.makeTransferEncoding(from: response.payload) == "chunked")
        #expect(HTTPEncoder.makeContentLength(from: response.payload) == nil)
    }

    @Test
    func response_keepsProvidedHeaders() {
        let response = HTTPResponse(
            headers: [.contentType: "text/event-stream; charset=utf-8", .cacheControl: "no-store"],
            serverSentEvents: AsyncStream<SSEEvent> { $0.finish() }
        )
        #expect(response.headers[.contentType] == "text/event-stream; charset=utf-8")
        #expect(response.headers[.cacheControl] == "no-store")
    }

    @Test
    func request_lastEventID() {
        #expect(HTTPRequest.make(headers: [.lastEventID: "41"]).lastEventID == "41")
        #expect(HTTPRequest.make().lastEventID == nil)
    }

    @Test
    func bytes_areOneBufferPerEvent() async throws {
        let bytes = SSEEventBytes(events: [SSEEvent(data: "a"), SSEEvent(data: "b")].async, heartbeat: nil, capacity: 1)
        var iterator = bytes.makeAsyncIterator()
        #expect(try await iterator.nextString() == "data: a\n\n")
        #expect(try await iterator.nextString() == "data: b\n\n")
        #expect(try await iterator.nextString() == nil)
    }

    @Test
    func largeEvent_isSplitIntoSuggestedBuffers() async throws {
        let bytes = SSEEventBytes(events: [SSEEvent(data: "abcdef")].async, heartbeat: nil, capacity: 1)
        var iterator = bytes.makeAsyncIterator()
        #expect(try await iterator.nextString(suggested: 4) == "data")
        #expect(try await iterator.nextString(suggested: 4) == ": ab")
        #expect(try await iterator.nextString(suggested: 100) == "cdef\n\n")
        #expect(try await iterator.nextString() == nil)
    }

    @Test
    func heartbeat_isSentWhileIdle() async throws {
        let (events, continuation) = AsyncStream<SSEEvent>.makeStream()
        let bytes = SSEEventBytes(events: events, heartbeat: 0.01, capacity: 1)
        var iterator = bytes.makeAsyncIterator()
        #expect(try await iterator.nextString() == ":\n\n")
        continuation.yield(SSEEvent(data: "a"))
        continuation.finish()
        var remaining = [String]()
        while let next = try await iterator.nextString() {
            remaining.append(next)
        }
        #expect(remaining.contains("data: a\n\n"))
    }

    @Test
    func infiniteHeartbeat_doesNotTrap() async throws {
        let bytes = SSEEventBytes(events: [SSEEvent(data: "a")].async, heartbeat: .infinity, capacity: 1)
        var iterator = bytes.makeAsyncIterator()
        #expect(try await iterator.nextString() == "data: a\n\n")
        #expect(try await iterator.nextString() == nil)
    }

    @Test
    func slowReader_limitsEventsRead() async throws {
        let counter = CountingEvents()
        let bytes = SSEEventBytes(events: counter, heartbeat: nil, capacity: 4)
        var iterator = bytes.makeAsyncIterator()
        _ = try await iterator.nextString()

        // capacity buffered, plus one handed off and one waiting to send
        try await waitUntil { counter.count >= 5 }
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(counter.count <= 6)
    }

    @Test
    func releasingIterator_cancelsEvents() async throws {
        let terminated = Mutex(false)
        let events = AsyncStream<SSEEvent> {
            $0.yield(SSEEvent(data: "a"))
            $0.onTermination = { _ in terminated.withLock { $0 = true } }
        }
        do {
            let bytes = SSEEventBytes(events: events, heartbeat: nil, capacity: 1)
            var iterator = bytes.makeAsyncIterator()
            #expect(try await iterator.nextString() == "data: a\n\n")
        }
        try await waitUntil { terminated.withLock { $0 } }
    }

    @Test
    func throwingEvents_failStream() async throws {
        let events = AsyncThrowingStream<SSEEvent, any Error> {
            $0.yield(SSEEvent(data: "a"))
            $0.finish(throwing: SocketError.disconnected)
        }
        let bytes = SSEEventBytes(events: events, heartbeat: nil, capacity: 1)
        var iterator = bytes.makeAsyncIterator()
        #expect(try await iterator.nextString() == "data: a\n\n")
        await #expect(throws: SocketError.self) { try await iterator.nextString() }
    }

    // MARK: - Server

    @Test
    func server_streamsEventsBeyondHandlerTimeout() async throws {
        let server = HTTPServer.make(timeout: 0.1) { request in
            let lastID = Int(request.lastEventID ?? "0") ?? 0
            let events = AsyncStream<SSEEvent> { continuation in
                let task = Task {
                    for id in (lastID + 1)...(lastID + 3) {
                        try await Task.sleep(nanoseconds: 100_000_000)
                        continuation.yield(try SSEEvent(data: "tick", id: String(id)))
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
            return HTTPResponse(serverSentEvents: events)
        }
        let task = Task { try await server.run() }
        defer { task.cancel() }
        let port = try await server.waitForListeningPort()
        let socket = try await AsyncSocket.connected(to: .inet(ip4: "127.0.0.1", port: port))
        defer { try? socket.socket.close() }
        try await socket.writeRequest(.make("/events", headers: [.lastEventID: "10"]))
        let response = try await socket.readResponse()
        #expect(response.headers[.contentType] == "text/event-stream")
        #expect(response.headers[.transferEncoding] == "chunked")
        #expect(
            try await response.bodyString == "id: 11\ndata: tick\n\nid: 12\ndata: tick\n\nid: 13\ndata: tick\n\n"
        )
        await server.stop()
    }

    @Test
    func server_cancelsEvents_whenClientDisconnects() async throws {
        let terminated = Mutex(false)
        let server = HTTPServer.make { _ in
            let events = AsyncStream<SSEEvent> {
                $0.yield(SSEEvent(data: "hello"))
                $0.onTermination = { _ in terminated.withLock { $0 = true } }
            }
            return HTTPResponse(serverSentEvents: events, heartbeat: 0.01)
        }
        let task = Task { try await server.run() }
        defer { task.cancel() }
        let port = try await server.waitForListeningPort()

        let socket = try await AsyncSocket.connected(to: .inet(ip4: "127.0.0.1", port: port))
        try await socket.writeRequest(.make("/events"))
        // readResponse() buffers a chunked body until it ends, so read the raw bytes
        let head = try await socket.readString(until: "data: hello\n\n")
        #expect(head.contains("Content-Type: text/event-stream"))
        try await socket.close()

        // a heartbeat write fails once the client has gone
        try await waitUntil { terminated.withLock { $0 } }
        await server.stop()
    }

    @Test
    func server_cancelsEvents_whenStopped() async throws {
        let terminated = Mutex(false)
        let server = HTTPServer.make { _ in
            let events = AsyncStream<SSEEvent> {
                $0.yield(SSEEvent(data: "hello"))
                $0.onTermination = { _ in terminated.withLock { $0 = true } }
            }
            return HTTPResponse(serverSentEvents: events, heartbeat: nil)
        }
        let task = Task { try await server.run() }
        let port = try await server.waitForListeningPort()

        let socket = try await AsyncSocket.connected(to: .inet(ip4: "127.0.0.1", port: port))
        defer { try? socket.socket.close() }
        try await socket.writeRequest(.make("/events"))
        _ = try await socket.readString(until: "data: hello\n\n")

        await server.stop(timeout: 0)
        _ = try? await task.value
        try await waitUntil { terminated.withLock { $0 } }
    }
}

private extension SSEEvent {
    var string: String { String(decoding: encoded, as: UTF8.self) }
}

private extension SSEEventBytes.Iterator {
    mutating func nextString(suggested: Int = 4096) async throws -> String? {
        try await nextBuffer(suggested: suggested).map { String(decoding: $0, as: UTF8.self) }
    }
}

private extension AsyncSocket {
    func readString(until suffix: String) async throws -> String {
        var bytes = [UInt8]()
        while !String(decoding: bytes, as: UTF8.self).contains(suffix) {
            bytes += try await read(atMost: 4096)
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}

/// Polls until `condition` is true, failing after `timeout` so a test can't hang.
private func waitUntil(timeout: TimeInterval = 5, _ condition: () async -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while await !condition() {
        guard Date() < deadline else {
            throw SocketError.makeTaskTimeout(seconds: timeout)
        }
        try await Task.sleep(nanoseconds: 1_000_000)
    }
}

/// An endless sequence of events that counts how many have been read.
private final class CountingEvents: AsyncSequence, Sendable {
    typealias Element = SSEEvent
    private let state = Mutex(0)

    var count: Int { state.withLock { $0 } }

    func makeAsyncIterator() -> Iterator { Iterator(events: self) }

    struct Iterator: AsyncIteratorProtocol {
        let events: CountingEvents
        mutating func next() async -> SSEEvent? {
            let count = events.state.withLock { $0 += 1; return $0 }
            return SSEEvent(data: String(count))
        }
    }
}

private struct ArraySequence<Element: Sendable>: AsyncSequence, Sendable {
    let elements: [Element]
    func makeAsyncIterator() -> Iterator { Iterator(elements: elements[...]) }
    struct Iterator: AsyncIteratorProtocol {
        var elements: ArraySlice<Element>
        mutating func next() async -> Element? { elements.popFirst() }
    }
}

private extension Array where Element: Sendable {
    var async: ArraySequence<Element> { ArraySequence(elements: self) }
}
