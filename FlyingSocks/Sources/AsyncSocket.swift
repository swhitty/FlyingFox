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

public extension AsyncSocketPool where Self == SocketPool<Poll> {

    @available(*, unavailable, renamed: "client")
    static var pollingClient: Self {
        fatalError("use .client")
    }

    static var client: some AsyncSocketPool {
        get async throws {
            try await ClientPoolLoader.shared.getPool()
        }
    }
}

public struct AsyncSocket: Sendable {

    public let socket: Socket
    let pool: any AsyncSocketPool

    public init(socket: Socket, pool: some AsyncSocketPool) throws {
        self.socket = socket
        self.pool = pool
        try socket.setFlags(.nonBlocking)
    }

    public static func connected(to address: some SocketAddress, timeout: TimeInterval = 5) async throws -> Self {
        try await connected(
            to: address,
            pool: ClientPoolLoader.shared.getPool(),
            timeout: timeout
        )
    }

    public static func connected(to address: some SocketAddress,
                                 pool: some AsyncSocketPool,
                                 timeout: TimeInterval = 5) async throws -> Self {
        try await withThrowingTimeout(seconds: timeout) {
            let socket = try Socket(domain: Int32(address.makeStorage().ss_family), type: Socket.stream)
            let asyncSocket = try AsyncSocket(socket: socket, pool: pool)
            try await asyncSocket.connect(to: address)
            return asyncSocket
        }
    }

    @Sendable
    public func accept() async throws -> AsyncSocket {
        try await pool.loopUntilReady(for: .connection, on: socket) {
            let file = try socket.accept().file
            let socket = Socket(file: file)
            return try AsyncSocket(socket: socket, pool: pool)
        }
    }

    public func connect(to address: some SocketAddress) async throws {
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
            try Task.checkCancellation()
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

    /// Reads bytes from the socket up to by not over/
    /// - Parameter bytes: The max number of bytes to read
    /// - Returns: an array of the read bytes capped to the number of bytes provided.
    public func read(atMost bytes: Int) async throws -> [UInt8] {
        guard bytes > 0 else { return [] }

        var data: [UInt8]?
        repeat {
            try Task.checkCancellation()
            do {
                data = try socket.read(atMost: min(bytes, 4096))
            } catch SocketError.blocked {
                try await pool.suspendSocket(socket, untilReadyFor: .read)
            } catch {
                throw error
            }
        } while data == nil

        return data!
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

public struct AsyncSocketReadSequence: AsyncBufferedSequence, AsyncBufferedIteratorProtocol, Sendable {
    public typealias Element = UInt8

    let socket: AsyncSocket

    public func makeAsyncIterator() -> AsyncSocketReadSequence { self }

    public mutating func next() async throws -> UInt8? {
        return try await socket.read()
    }

    public func nextBuffer(atMost count: Int) async throws -> [Element]? {
        try await socket.read(atMost: count)
    }
}

extension AsyncSocketReadSequence: AsyncChunkedSequence, AsyncChunkedIteratorProtocol {

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

private actor ClientPoolLoader {
    static let shared = ClientPoolLoader()

    private let pool: some AsyncSocketPool = SocketPool.make()
    private var isStarted = false

    func getPool() async throws -> some AsyncSocketPool {
        guard !isStarted else {
            return pool
        }
        try await pool.prepare()
        isStarted = true
        Task { try await pool.run() }
        return pool
    }
}

