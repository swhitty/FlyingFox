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
        let handler = WebSocketHTTPHander.make()

        let response = try await handler.handleRequest(.make(headers: [.webSocketKey: "ABC"]))

        XCTAssertEqual(
            response.statusCode,
            .switchingProtocols
        )
        XCTAssertEqual(
            response.headers[.webSocketAccept],
            "YaxQU85y1o0znnviL0CeoKg7QTM="
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

    func testWebSocketKey_IsCreatedFromUUID() async throws {
        XCTAssertEqual(
            WebSocketHTTPHander.makeSecWebSocketKeyValue(for: UUID(uuidString: "123e4567-e89b-12d3-a456-426614174000")!),
            "Ej5FZ+ibEtOkVkJmFBdAAA=="
        )

        XCTAssertNotEqual(
            WebSocketHTTPHander.makeSecWebSocketKeyValue(),
            "Ej5FZ+ibEtOkVkJmFBdAAA=="
        )
    }

}

private extension WebSocketHTTPHander {
    static func make(handler: WSHandler = MockHandler()) -> WebSocketHTTPHander {
        WebSocketHTTPHander(handler: MockHandler())
    }
}

private struct MockHandler: WSHandler {
    func makeFrames(for client: WSFrameSequence) async throws -> WSFrameSequence {
        client
    }
}
