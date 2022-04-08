//
//  WebSocketHandlerTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 19/03/2022.
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

final class WebSocketHandlerTests: XCTestCase {

    func testResponseIncludesExpectedHeaders() async throws {
        let handler = WebSocketHTTPHandler.make()

        let response = try await handler.handleRequest(.make(
            headers: [
                .host: "localhost",
                .connection: "uPgRaDe,Keep-Alive", // case-insensitive and can be a list of values
                .upgrade: "WeBsOcKeT", // case-insensitive
                .webSocketKey: "ABCDEFGHIJKLMNOP".data(using: .utf8)!.base64EncodedString(),
                .webSocketVersion: "13"
            ]
        ))

        XCTAssertEqual(
            response.statusCode,
            .switchingProtocols
        )
        XCTAssertEqual(
            response.headers[.webSocketAccept],
            "9twnCz4Oi2Q3EuDqLAETCuip07c="
        )
        XCTAssertEqual(
            response.headers[.connection],
            "upgrade"
        )
        XCTAssertEqual(
            response.headers[.upgrade],
            "websocket"
        )
    }

    func testHandlerVerifiesHeaders() async throws {
        // Checks for conformance to RFC 6455 section 4.2.1 (https://datatracker.ietf.org/doc/html/rfc6455#section-4.2.1)

        let handler = WebSocketHTTPHandler.make()

        let headers: [HTTPHeader: String] = [
            .host: "localhost",
            .connection: "Upgrade",
            .upgrade: "websocket",
            .webSocketKey: "ABCDEFGHIJKLMNOP".data(using: .utf8)!.base64EncodedString(),
            .webSocketVersion: "13"
        ]

        var withoutHostHeaders = headers
        withoutHostHeaders[.host] = nil

        var incorrectConnectionHeaders = headers
        incorrectConnectionHeaders[.connection] = "Downgrade"

        var incorrectUpgradeHeaders = headers
        incorrectUpgradeHeaders[.upgrade] = "webplugs"

        var incorrectSocketKeyHeaders = headers
        incorrectSocketKeyHeaders[.webSocketKey] = "ABC"

        var incorrectSocketVersionHeaders = headers
        incorrectSocketVersionHeaders[.webSocketVersion] = "-1"

        let withoutHostResponse = try await handler.handleRequest(.make(headers: withoutHostHeaders))
        XCTAssertEqual(
            withoutHostResponse.statusCode,
            .badRequest
        )

        let incorrectConnectionResponse = try await handler.handleRequest(.make(headers: incorrectConnectionHeaders))
        XCTAssertEqual(
            incorrectConnectionResponse.statusCode,
            .badRequest
        )

        let incorrectUpgradeResponse = try await handler.handleRequest(.make(headers: incorrectUpgradeHeaders))
        XCTAssertEqual(
            incorrectUpgradeResponse.statusCode,
            .badRequest
        )

        let incorrectSocketKeyResponse = try await handler.handleRequest(.make(headers: incorrectSocketKeyHeaders))
        XCTAssertEqual(
            incorrectSocketKeyResponse.statusCode,
            .badRequest
        )

        let incorrectSocketVersionResponse = try await handler.handleRequest(.make(headers: incorrectSocketVersionHeaders))
        XCTAssertEqual(
            incorrectSocketVersionResponse.statusCode,
            .badRequest
        )
    }

    func testWebSocketKey_IsCreatedFromUUID() async throws {
        XCTAssertEqual(
            WebSocketHTTPHandler.makeSecWebSocketKeyValue(for: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!),
            "Ej5FZ+ibEtOkVkJmFBdAAA=="
        )

        XCTAssertNotEqual(
            WebSocketHTTPHandler.makeSecWebSocketKeyValue(),
            "Ej5FZ+ibEtOkVkJmFBdAAA=="
        )
    }

}

private extension WebSocketHTTPHandler {
    static func make(handler: WSHandler = MockHandler()) -> WebSocketHTTPHandler {
        WebSocketHTTPHandler(handler: MockHandler())
    }
}

private struct MockHandler: WSHandler {
    func makeFrames(for client: AsyncThrowingStream<WSFrame, Error>) async throws -> AsyncStream<WSFrame> {
        var iterator = client.makeAsyncIterator()
        return AsyncStream<WSFrame> {
            try? await iterator.next()
        }
    }
}
