//
//  WebSocketHTTPHander.swift
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

public struct WebSocketHTTPHander: HTTPHandler, Sendable {

    private let handler: WSHandler

    public init(handler: WSHandler) {
        self.handler = handler
    }

    public func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        var response = HTTPResponse(webSocket: handler)
        response.headers[.connection] = "upgrade"
        response.headers[.upgrade] = "websocket"
        if let key = request.headers[.webSocketKey] {
            response.headers[.webSocketAccept] = Self.makeSecWebSocketAcceptValue(for: key)
        }

        return response
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
