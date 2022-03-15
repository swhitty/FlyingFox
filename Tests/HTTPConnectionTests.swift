//
//  HTTPConnectionTests.swift
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
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class HTTPConnectionTests: XCTestCase {

    let pool: AsyncSocketPool = PollingSocketPool()
    var task: Task<Void, Error>?

    override func setUp() {
        task = Task { try await pool.run() }
    }

    override func tearDown() {
        task?.cancel()
    }

    func testConnection_ReceivesRequest() async throws {
        let (s1, s2) = try AsyncSocket.makePair(pool: pool)

        let connection = HTTPConnection(socket: s1)
        try await s2.writeString(
            """
            GET /hello/world HTTP/1.1\r
            Content-Length: 5
            \r
            Hello

            """
        )

        let request = try await connection.requests.first()
        XCTAssertEqual(
            request,
            .make(method: .GET,
                  version: .http11,
                  path: "/hello/world",
                  headers: [.contentLength: "5"],
                  body: "Hello".data(using: .utf8)!)
        )

        try s1.close()
        try s2.close()
    }

    func testConnectionRequestsAreReceived_WhileConnectionIsKeptAlive() async throws {
        let (s1, s2) = try AsyncSocket.makePair(pool: pool)

        let connection = HTTPConnection(socket: s1)
        try await s2.writeString(
            """
            GET /hello HTTP/1.1\r
            Connection: Keep-Alive\r
            \r
            GET /hello HTTP/1.1\r
            Connection: Keep-Alive\r
            \r
            GET /hello HTTP/1.1\r
            \r

            """
        )

        let count = try await connection.requests.reduce(0, { count, _ in count + 1 })
        XCTAssertEqual(count, 3)

        try s1.close()
        try s2.close()
    }

    func testConnectionResponse_IsSent() async throws {
        let (s1, s2) = try AsyncSocket.makePair(pool: pool)

        let connection = HTTPConnection(socket: s1)

        try await connection.sendResponse(
            .make(version: .http11,
                  statusCode: .gone)
        )

        let response = try await s2.readString(length: 40)
        XCTAssertEqual(
            response,
            """
            HTTP/1.1 410 Gone\r
            Content-Length: 0\r
            \r

            """
        )
    }

    func testConnectionDisconnects_WhenErrorIsReceived() async throws {
        let (s1, s2) = try AsyncSocket.makePair(pool: pool)

        try s2.close()
        let connection = HTTPConnection(socket: s1)

        let count = try await connection.requests.reduce(0, { count, _ in count + 1 })
        XCTAssertEqual(count, 0)

        try connection.close()
    }

    func testConnectionHostName() {
        XCTAssertEqual(
            HTTPConnection.makeIdentifer(from: .ip4("8.8.8.8", port: 8080)),
            "8.8.8.8"
        )
        XCTAssertEqual(
            HTTPConnection.makeIdentifer(from: .ip6("::1", port: 8080)),
            "::1"
        )
        XCTAssertEqual(
            HTTPConnection.makeIdentifer(from: .unix("/var/sock/fox")),
            "/var/sock/fox"
        )
    }
}

extension AsyncSequence {
    func first() async throws -> Element {
        guard let next = try await first(where: { _ in true }) else {
            throw AsyncSequenceError("Premature termination")
        }
        return next
    }
}
