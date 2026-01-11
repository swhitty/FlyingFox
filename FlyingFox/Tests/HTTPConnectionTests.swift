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
import FlyingSocks
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing

struct HTTPConnectionTests {

    @Test
    func connection_ReceivesRequest() async throws {
        let (s1, s2) = try await AsyncSocket.makePair()

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
        #expect(
            await request == .make(
                method: .GET,
                version: .http11,
                path: "/hello/world",
                headers: [.contentLength: "5"],
                body: "Hello".data(using: .utf8)!
            )
        )

        try s1.close()
        try s2.close()
    }

    @Test
    func connectionRequestsAreReceived_WhileConnectionIsKeptAlive() async throws {
        let (s1, s2) = try await AsyncSocket.makePair()

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
        #expect(count == 3)

        try s1.close()
        try s2.close()
    }

    @Test
    func connectionResponse_IsSent() async throws {
        let (s1, s2) = try await AsyncSocket.makePair()

        let connection = HTTPConnection(socket: s1)

        try await connection.sendResponse(
            .make(version: .http11,
                  statusCode: .gone,
                  body: "Hello World!".data(using: .utf8)!)
        )

        let response = try await s2.readString(length: 53)
        #expect(
            response == """
            HTTP/1.1 410 Gone\r
            Content-Length: 12\r
            \r
            Hello World!
            """
        )
    }

    @Test
    func connectionDisconnects_WhenErrorIsReceived() async throws {
        let (s1, s2) = try await AsyncSocket.makePair()

        try s2.close()
        let connection = HTTPConnection(socket: s1)

        let count = try await connection.requests.reduce(0, { count, _ in count + 1 })
        #expect(count == 0)

        try connection.close()
    }

    @Test
    func connectionHostName() {
        #expect(
            HTTPConnection.makeIdentifer(from: .ip4("8.8.8.8", port: 8080)) == "8.8.8.8"
        )
        #expect(
            HTTPConnection.makeIdentifer(from: .ip6("::1", port: 8080)) == "::1"
        )
        #expect(
            HTTPConnection.makeIdentifer(from: .unix("/var/sock/fox")) == "/var/sock/fox"
        )
    }
}

private extension HTTPConnection {
    init(socket: AsyncSocket) {
        self.init(
            socket: socket,
            decoder: HTTPDecoder.make(),
            logger: .disabled
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

extension HTTPRequest {
    static func ==(lhs: HTTPRequest, rhs: HTTPRequest) async -> Bool {
        let lhsData = try? await lhs.bodyData
        let rhsData = try? await rhs.bodyData
        guard let lhsData, let rhsData else { return false }
        return lhs.method == rhs.method &&
               lhs.version == rhs.version &&
               lhs.path == rhs.path &&
               lhs.query == rhs.query &&
               lhs.headers == rhs.headers &&
               lhsData == rhsData
    }
}
