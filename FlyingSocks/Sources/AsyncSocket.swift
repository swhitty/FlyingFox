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

    public struct Message: Sendable {
        public let peerAddress: sockaddr_storage
        public let bytes: [UInt8]
        public let interfaceIndex: UInt32?
        public let localAddress: sockaddr_storage?

        public init(
            peerAddress: sockaddr_storage,
            bytes: [UInt8],
            interfaceIndex: UInt32? = nil,
            localAddress: sockaddr_storage? = nil
        ) {
            self.peerAddress = peerAddress
            self.bytes = bytes
            self.interfaceIndex = interfaceIndex
            self.localAddress = localAddress
        }
    }

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
            let socket = try Socket(domain: Int32(type(of: address).family), type: .stream)
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

    public func receive(atMost length: Int = 4096) async throws -> (sockaddr_storage, [UInt8]) {
        try Task.checkCancellation()

        repeat {
            do {
                return try socket.receive(length: length)
            } catch SocketError.blocked {
                try await pool.suspendSocket(socket, untilReadyFor: .read)
            } catch {
                throw error
            }
        } while true
    }

#if !canImport(WinSDK)
    public func receive(atMost length: Int) async throws -> Message {
        try Task.checkCancellation()

        repeat {
            do {
                let (peerAddress, bytes, interfaceIndex, localAddress) = try socket.receive(length: length)
                return Message(peerAddress: peerAddress, bytes: bytes, interfaceIndex: interfaceIndex, localAddress: localAddress)
            } catch SocketError.blocked {
                try await pool.suspendSocket(socket, untilReadyFor: .read)
            } catch {
                throw error
            }
        } while true
    }
#endif

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

    public func send(_ data: [UInt8], to address: some SocketAddress) async throws {
        let sent = try await pool.loopUntilReady(for: .write, on: socket) {
            try socket.send(data, to: address)
        }
        guard sent == data.count else {
            throw SocketError.disconnected
        }
    }

    public func send(_ data: Data, to address: some SocketAddress) async throws {
        try await send(Array(data), to: address)
    }

#if !canImport(WinSDK)
    public func send(
        message: [UInt8],
        to peerAddress: some SocketAddress,
        interfaceIndex: UInt32? = nil,
        from localAddress: (some SocketAddress)? = nil
    ) async throws {
        let sent = try await pool.loopUntilReady(for: .write, on: socket) {
            try socket.send(message: message, to: peerAddress, interfaceIndex: interfaceIndex, from: localAddress)
        }
        guard sent == message.count else {
            throw SocketError.disconnected
        }
    }

    public func send(
        message: Data,
        to peerAddress: some SocketAddress,
        interfaceIndex: UInt32? = nil,
        from localAddress: (some SocketAddress)? = nil
    ) async throws {
        try await send(message: Array(message), to: peerAddress, interfaceIndex: interfaceIndex, from: localAddress)
    }
#endif

    public func close() throws {
        try socket.close()
    }

    public var bytes: AsyncSocketReadSequence {
        AsyncSocketReadSequence(socket: self)
    }

    public var sockets: AsyncSocketSequence {
        AsyncSocketSequence(socket: self)
    }

    public var messages: AsyncSocketMessageSequence {
        AsyncSocketMessageSequence(socket: self)
    }

    public func messages(maxMessageLength: Int) -> AsyncSocketMessageSequence {
        AsyncSocketMessageSequence(socket: self, maxMessageLength: maxMessageLength)
    }
}

package extension AsyncSocket {

    static func makePair(pool: some AsyncSocketPool, type: SocketType = .stream) throws -> (AsyncSocket, AsyncSocket) {
        let (s1, s2) = try Socket.makePair(type: type)
        let a1 = try AsyncSocket(socket: s1, pool: pool)
        let a2 = try AsyncSocket(socket: s2, pool: pool)
        return (a1, a2)
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

    public func nextBuffer(suggested count: Int) async throws -> [Element]? {
        try await socket.read(atMost: count)
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

public struct AsyncSocketMessageSequence: AsyncSequence, AsyncIteratorProtocol, Sendable {
    public static let DefaultMaxMessageLength: Int = 1500

    // Windows has a different recvmsg() API signature which is presently unsupported
    public typealias Element = AsyncSocket.Message

    private let socket: AsyncSocket
    private let maxMessageLength: Int

    public func makeAsyncIterator() -> AsyncSocketMessageSequence { self }

    init(socket: AsyncSocket, maxMessageLength: Int = Self.DefaultMaxMessageLength) {
        self.socket = socket
        self.maxMessageLength = maxMessageLength
    }

    public mutating func next() async throws -> Element? {
#if !canImport(WinSDK)
        try await socket.receive(atMost: maxMessageLength)
#else
        let peerAddress: sockaddr_storage
        let bytes: [UInt8]

        (peerAddress, bytes) = try await socket.receive(atMost: maxMessageLength)
        return AsyncSocket.Message(peerAddress: peerAddress, bytes: bytes)
#endif
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

