//
//  WebSocketHTTPHandler.swift
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

import Foundation

public struct WSInvalidHandshakeError: LocalizedError {
    public var errorDescription: String?

    init(_ message: String) {
        self.errorDescription = message
    }
}

public struct WebSocketHTTPHandler: HTTPHandler, Sendable {

    private let handler: any WSHandler
    private let acceptedMethods: Set<HTTPMethod>

    public init(handler: some WSHandler, accepts methods: Set<HTTPMethod> = [.GET]) {
        self.handler = handler
        self.acceptedMethods = methods
    }

    public func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        // Get the request's key and verify the headers
        let key: String
        do {
            try Self.verifyHandshakeRequestMethod(request.method, accepted: acceptedMethods)
            key = try Self.verifyHandshakeRequestHeaders(request.headers)
        } catch {
            return HTTPResponse(
                version: .http11,
                statusCode: .badRequest,
                headers: [:],
                body: error.localizedDescription.data(using: .utf8)!
            )
        }

        // Create the response
        var response = HTTPResponse(webSocket: handler)
        response.headers[.connection] = "upgrade"
        response.headers[.upgrade] = "websocket"
        response.headers[.webSocketAccept] = Self.makeSecWebSocketAcceptValue(for: key)

        return response
    }

    /// Verifies a handshake request's headers and returns the request's key.
    /// - Parameter headers: The headers of the request to verify.
    /// - Returns: The request's key.
    /// - Throws: An ``WSInvalidHandshakeError`` if the headers are invalid.
    static func verifyHandshakeRequestHeaders(_ headers: HTTPHeaders) throws -> String {
        // Verify the headers according to RFC 6455 section 4.2.1 (https://datatracker.ietf.org/doc/html/rfc6455#section-4.2.1)
        // Rule 1 isn't verified because the socket method is specified elsewhere

        // 2. A |Host| header field containing the server's authority.
        guard headers[.host] != nil else {
            throw WSInvalidHandshakeError("Host header must be present")
        }

        // 3. An |Upgrade| header field containing the value "websocket", treated as an ASCII
        //    case-insensitive value.
        guard headers[.upgrade]?.lowercased() == "websocket" else {
            throw WSInvalidHandshakeError("Upgrade header must be 'websocket'")
        }

        // 4. A |Connection| header field that includes the token "Upgrade", treated as an ASCII
        //    case-insensitive value.
        guard let connectionHeader = headers[.connection] else {
            throw WSInvalidHandshakeError("Connection header must must be present")
        }

        let connectionHeaderTokens = connectionHeader.lowercased().split(separator: ",").map { token in
            token.trimmingCharacters(in: .whitespaces)
        }
        guard connectionHeaderTokens.contains("upgrade") else {
            throw WSInvalidHandshakeError("Connection header must include 'Upgrade'")
        }

        // 5. A |Sec-WebSocket-Key| header field with a base64-encoded (see Section 4 of [RFC4648]) value that,
        //    when decoded, is 16 bytes in length.
        guard let key = headers[.webSocketKey] else {
            throw WSInvalidHandshakeError("Sec-WebSocket-Key header must be present")
        }

        guard Data(base64Encoded: key)?.count == 16 else {
            throw WSInvalidHandshakeError("Sec-WebSocket-Key header must be 16 bytes encoded as base64")
        }

        // 6. A |Sec-WebSocket-Version| header field, with a value of 13.
        guard headers[.webSocketVersion] == "13" else {
            throw WSInvalidHandshakeError("Sec-WebSocket-Version header must be '13'")
        }

        return key
    }

    /// Verifies a handshake request's method is accepted. RFC 6455 section 4.1 specicies only GET (https://datatracker.ietf.org/doc/html/rfc6455#section-4.1)
    /// - Parameters:
    ///   - method: the requests ``HTTMethod``.
    ///   - accepted: a Set of the accepted methods.
    /// - Throws: An ``WSInvalidHandshakeError`` if the method is not accepted.
    static func verifyHandshakeRequestMethod(_ method: HTTPMethod, accepted: Set<HTTPMethod>) throws {
        guard accepted.contains(method) else {
            throw WSInvalidHandshakeError("HTTP Request method cannot be upgraded to websocket")
        }
    }

    static func makeSecWebSocketAcceptValue(for key: String) -> String {
        SHA1
            .hash(data: (key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").data(using: .utf8)!)
            .base64EncodedString()
    }

    static func makeSecWebSocketKeyValue(for uuid: UUID = .init()) -> String {
        withUnsafeBytes(of: uuid.uuid) {
            Data($0).base64EncodedString()
        }
    }
}

@available(*, unavailable, renamed: "WebSocketHTTPHandler")
public typealias WebSocketHTTPHander = WebSocketHTTPHandler
