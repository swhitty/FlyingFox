//
//  AsyncSocket.swift
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

public protocol AsyncSocketPool: Sendable {

    /// Prepare the pool before running
    func prepare() async throws

    /// Runs the pool within the current task
    func run() async throws

    /// Suspends a socket, returning when the socket is ready for the requested events.
    /// - Parameters:
    ///   - socket: Socket that is blocked and is waiting for events
    ///   - events: The events the socket is waiting to become available
    func suspendSocket(_ socket: Socket, untilReadyFor events: Socket.Events) async throws
}

public extension AsyncSocketPool where Self == EventQueueSocketPool<Poll> {
    static var pollingClient: AsyncSocketPool {
        EventQueueSocketPool<Poll>.client
    }
}

public struct AsyncSocket: Sendable {

    public let socket: Socket
    let pool: AsyncSocketPool

    public init(socket: Socket, pool: AsyncSocketPool = .pollingClient) throws {
        self.socket = socket
        self.pool = pool
        try socket.setFlags(.nonBlocking)
    }

    public static func connected<A: SocketAddress>(to address: A,  pool: AsyncSocketPool = .pollingClient) async throws -> Self {
        let socket = try Socket(domain: Int32(address.makeStorage().ss_family), type: Socket.stream)
        let asyncSocket = try AsyncSocket(socket: socket, pool: pool)
        try await asyncSocket.connect(to: address)
        return asyncSocket
    }

    @Sendable
    public func accept() async throws -> AsyncSocket {
        try await pool.loopUntilReady(for: .connection, on: socket) {
            let file = try socket.accept().file
            let socket = Socket(file: file)
            return try AsyncSocket(socket: socket, pool: pool)
        }
    }

    public func connect<A: SocketAddress>(to address: A) async throws {
        return try await pool.loopUntilReady(for: [.write], on: socket) {
            try socket.connect(to: address)
        }
    }

    public func read() async throws -> UInt8 {
        try await pool.loopUntilReady(for: .read, on: socket) {
            try socket.read()
        }
    }

    public func read(bytes: Int) async throws -> [UInt8] {
        guard bytes > 0 else { return [] }

        var buffer = [UInt8]()
        while buffer.count < bytes {
            let toRead = min(bytes - buffer.count, 4096)
            do {
                try buffer.append(contentsOf: socket.read(atMost: toRead))
            } catch SocketError.blocked {
                try await pool.suspendSocket(socket, untilReadyFor: .read)
            } catch {
                throw error
            }
        }
        return buffer
    }

    public func write(_ data: Data) async throws {
        var sent = data.startIndex
        while sent < data.endIndex {
            sent = try await write(data, from: sent)
        }
    }

    private func write(_ data: Data, from index: Data.Index) async throws -> Data.Index {
        try await pool.loopUntilReady(for: .write, on: socket) {
            try socket.write(data, from: index)
        }
    }

    public func close() throws {
        try socket.close()
    }

    public var bytes: AsyncSocketReadSequence {
        AsyncSocketReadSequence(socket: self)
    }

    public var sockets: AsyncSocketSequence {
        AsyncSocketSequence(socket: self)
    }
}

private extension AsyncSocketPool {

    func loopUntilReady<T>(for events: Socket.Events, on socket: Socket, body: () throws -> T) async throws -> T {
        var result: T?
        repeat {
            do {
                result = try body()
            } catch SocketError.blocked {
                try await suspendSocket(socket, untilReadyFor: events)
            } catch {
                throw error
            }
        } while result == nil
        return result!
    }
}

public struct AsyncSocketReadSequence: ChunkedAsyncSequence, ChunkedAsyncIteratorProtocol, Sendable {
    public typealias Element = UInt8

    let socket: AsyncSocket

    public func makeAsyncIterator() -> AsyncSocketReadSequence { self }

    public mutating func next() async throws -> UInt8? {
        return try await socket.read()
    }

    public mutating func nextChunk(count: Int) async throws -> [Element]? {
        return try await socket.read(bytes: count)
    }
}

public struct AsyncSocketSequence: AsyncSequence, AsyncIteratorProtocol, Sendable {
    public typealias Element = AsyncSocket

    let socket: AsyncSocket

    public func makeAsyncIterator() -> AsyncSocketSequence { self }

    public mutating func next() async throws -> AsyncSocket? {
        do {
            return try await socket.accept()
        } catch SocketError.disconnected {
            return nil
        } catch {
            throw error
        }
    }
}
