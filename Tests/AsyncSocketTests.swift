//
//  AsyncSocketTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 22/02/2022.
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

@testable import FlyingFox
import XCTest

final class AsyncSocketTests: XCTestCase {

    let pool: AsyncSocketPool = PollingSocketPool()
    var task: Task<Void, Error>?

    override func setUp() {
        task = Task { try await pool.run() }
    }

    override func tearDown() {
        task?.cancel()
    }

    func testSocketReadsByte_WhenAvailable() async throws {
        let (s1, s2) = try AsyncSocket.makePair(pool: pool)

        async let d2 = s2.read()
        try await s1.write(Data([10]))
        let v2 = try await d2
        XCTAssertEqual(v2, 10)

        try s1.close()
        try s2.close()
    }

    func testSocketReadsChunk_WhenAvailable() async throws {
        let (s1, s2) = try AsyncSocket.makePair(pool: pool)

        async let d2 = s2.readString(length: 12)
        Task {
            try await s1.writeString("Fish & Chips")
        }

        let text = try await d2
        XCTAssertEqual(text, "Fish & Chips")
    }

    func testSocketWrite_WaitsWhenBufferIsFull() async throws {
        let (s1, s2) = try AsyncSocket.makePair(pool: pool)
        try s1.socket.setValue(1024, for: .sendBufferSize)

        let task = Task {
            try await s1.write(Data(repeating: 0x01, count: 8192))
        }

        _ = try await s2.read(bytes: 8192)
        try await task.value
    }

    func testSocketReadByte_ThrowsDisconnected_WhenSocketIsClosed() async throws {
        let s1 = try AsyncSocket.make(pool: pool)
        try s1.close()

        await XCTAssertThrowsError(try await s1.read(), of: SocketError.self) {
            XCTAssertEqual($0, .disconnected)
        }
    }

    func testSocketRead0Byte_ReturnsEmptyArray() async throws {
        let s1 = try AsyncSocket.make(pool: pool)

        let bytes = try await s1.read(bytes: 0)
        XCTAssertEqual(bytes, [])
    }

    func testSocketReadByte_Throws_WhenSocketIsNotOpen() async throws {
        let s1 = try AsyncSocket.make(pool: pool)

        await XCTAssertThrowsError(try await s1.read(), of: SocketError.self)
    }

    func testSocketReadChunk_ThrowsDisconnected_WhenSocketIsClosed() async throws {
        let s1 = try AsyncSocket.make(pool: pool)
        try s1.close()

        await XCTAssertThrowsError(try await s1.read(bytes: 5), of: SocketError.self) {
            XCTAssertEqual($0, .disconnected)
        }
    }

    func testSocketReadChunk_Throws_WhenSocketIsNotOpen() async throws {
        let s1 = try AsyncSocket.make(pool: pool)

        await XCTAssertThrowsError(try await s1.read(bytes: 5), of: SocketError.self)
    }

    func testSocketBytesReadChunk_ReturnsNil_WhenSocketIsClosed() async throws {
        let s1 = try AsyncSocket.make(pool: pool)
        try s1.close()

        var bytes = s1.bytes
        let chunk = try await bytes.nextChunk(count: 1)
        XCTAssertNil(chunk)
    }

    func testSocketBytesReadChunk_Throws_WhenSocketIsClosed() async throws {
        let s1 = try AsyncSocket.make(pool: pool)

        var bytes = s1.bytes
        await XCTAssertThrowsError(try await bytes.nextChunk(count: 1), of: SocketError.self)
    }

    func testSocketWrite_ThrowsDisconnected_WhenSocketIsClosed() async throws {
        let s1 = try AsyncSocket.make(pool: pool)
        try s1.close()

        await XCTAssertThrowsError(try await s1.writeString("Fish"), of: SocketError.self) {
            XCTAssertEqual($0, .disconnected)
        }
    }

    func testSocketWrite_Throws_WhenSocketIsNotConnected() async throws {
        let s1 = try AsyncSocket.make(pool: pool)
        await XCTAssertThrowsError(try await s1.writeString("Fish"), of: SocketError.self)
    }

    func testSocketAccept_Throws_WhenSocketIsClosed() async throws {
        let s1 = try AsyncSocket.make(pool: pool)

        await XCTAssertThrowsError(try await s1.accept(), of: SocketError.self)
    }

    func testSocket_Throws_WhenAlreadyCLosed() async throws {
        let s1 = try AsyncSocket.make(pool: pool)

        try s1.close()
        await XCTAssertThrowsError(try s1.close(), of: SocketError.self)
    }
}

extension AsyncSocket {

    static func make(pool: AsyncSocketPool) throws -> AsyncSocket {
        let socket = try Socket(domain: AF_UNIX, type: Socket.stream)
        return try AsyncSocket(socket: socket, pool: pool)
    }

    static func makePair(pool: AsyncSocketPool) throws -> (AsyncSocket, AsyncSocket) {
        let (file1, file2) = Socket.socketpair(AF_UNIX, Socket.stream, 0)
        guard file1 > -1, file2 > -1 else {
            throw SocketError.makeFailed("SocketPair")
        }

        let s1 = try AsyncSocket(socket: Socket(file: file1), pool: pool)
        let s2 = try AsyncSocket(socket: Socket(file: file2), pool: pool)
        return (s1, s2)
    }

    func writeString(_ string: String) async throws {
        try await write(string.data(using: .utf8)!)
    }

    func writeRequest(_ request: HTTPRequest) async throws {
        try await write(HTTPEncoder.encodeRequest(request))
    }

    func readResponse() async throws -> HTTPResponse {
        try await HTTPDecoder.decodeResponse(from: bytes)
    }

    func readString(length: Int) async throws -> String {
        let bytes = try await read(bytes: length)
        guard let string = String(data: Data(bytes), encoding: .utf8) else {
            throw SocketError.makeFailed("Read")
        }
        return string
    }
}
