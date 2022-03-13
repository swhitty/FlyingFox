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

protocol AsyncSocketPool: Sendable {
    func run() async throws

    func suspendUntilReady(for events: Socket.Events, on socket: Socket) async throws
}

struct AsyncSocket: Sendable {

    let socket: Socket
    let pool: AsyncSocketPool

    init(socket: Socket, pool: AsyncSocketPool) throws {
        self.socket = socket
        self.pool = pool
        try socket.setFlags(.nonBlocking)
    }

    func accept() async throws -> AsyncSocket {
        try await pool.loopUntilReady(for: [.read, .write], on: socket) {
            let file = try socket.accept().file
            let socket = Socket(file: file)
            return try AsyncSocket(socket: socket, pool: pool)
        }
    }

    func read() async throws -> UInt8 {
        try await pool.loopUntilReady(for: .read, on: socket) {
            try socket.read()
        }
    }

    func read(bytes: Int) async throws -> [UInt8] {
        guard bytes > 0 else { return [] }

        var buffer = [UInt8]()
        while buffer.count < bytes {
            let toRead = min(bytes - buffer.count, 4096)
            do {
                try buffer.append(contentsOf: socket.read(atMost: toRead))
            } catch SocketError.blocked {
                try await pool.suspendUntilReady(for: .read, on: socket)
            } catch {
                throw error
            }
        }
        return buffer
    }

    func write(_ data: Data) async throws {
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

    func close() throws {
        try socket.close()
    }

    var bytes: ByteSequence {
        ByteSequence(socket: self)
    }

    var sockets: ClosureSequence<AsyncSocket> {
        ClosureSequence(closure: accept)
    }
}

private extension AsyncSocketPool {

    func loopUntilReady<T>(for events: Socket.Events, on socket: Socket, body: () throws -> T) async throws -> T {
        var result: T?
        repeat {
            do {
                result = try body()
            } catch SocketError.blocked {
                try await suspendUntilReady(for: events, on: socket)
            } catch {
                throw error
            }
        } while result == nil
        return result!
    }
}

struct ByteSequence: ChunkedAsyncSequence, ChunkedAsyncIteratorProtocol {
    typealias Element = UInt8

    let socket: AsyncSocket

    func makeAsyncIterator() -> ByteSequence { self }

    mutating func next() async throws -> UInt8? {
        do {
            return try await socket.read()
        } catch SocketError.disconnected {
            return nil
        } catch {
            throw error
        }
    }

    mutating func nextChunk(count: Int) async throws -> [Element]? {
        do {
            return try await socket.read(bytes: count)
        } catch SocketError.disconnected {
            return nil
        } catch {
            throw error
        }
    }
}
