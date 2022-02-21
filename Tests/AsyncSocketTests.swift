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

        try await s1.close()
        try await s2.close()
    }

    func testSocketReadsChunk_WhenAvailable() async throws {
        let (s1, s2) = try AsyncSocket.makePair(pool: pool)

        async let d2 = s2.readString(length: 12)
        try await s1.writeString("Fish & Chips")
        let text = try await d2
        XCTAssertEqual(text, "Fish & Chips")
    }

    func testSocketReadByte_ThrowsDisconnected_WhenSocketIsClosed() async throws {
        let (s1, s2) = try AsyncSocket.makePair(pool: pool)
        try await s1.close()
        try await s2.close()
    
        await XCTAssertThrowsError(try await s1.read(), of: SocketError.self) {
            XCTAssertEqual($0, .disconnected)
        }
    }

    func testSocketReadChunk_ThrowsDisconnected_WhenSocketIsClosed() async throws {
        let (s1, s2) = try AsyncSocket.makePair(pool: pool)
        try await s1.close()
        try await s2.close()

        await XCTAssertThrowsError(try await s1.read(bytes: 5), of: SocketError.self) {
            XCTAssertEqual($0, .disconnected)
        }
    }

    func testSocketWrite_ThrowsDisconnected_WhenSocketIsClosed() async throws {
        let (s1, s2) = try AsyncSocket.makePair(pool: pool)
        try await s1.close()
        try await s2.close()

        await XCTAssertThrowsError(try await s1.writeString("Fish"), of: SocketError.self) {
            XCTAssertEqual($0, .disconnected)
        }
    }
}

extension AsyncSocket {

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

    func readString(length: Int) async throws -> String {
        let bytes = try await read(bytes: length)
        guard let string = String(data: Data(bytes), encoding: .utf8) else {
            throw SocketError.makeFailed("Read")
        }
        return string
    }
}
