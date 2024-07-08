//
//  HTTPResponse.swift
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

public struct HTTPResponse: Sendable {
    public var version: HTTPVersion
    public var statusCode: HTTPStatusCode
    public var headers: [HTTPHeader: String]
    public var payload: Payload

    public enum Payload: @unchecked Sendable {
        case httpBody(HTTPBodySequence)
        case webSocket(any WSHandler)

        @available(*, unavailable, renamed: "httpBody")
        static func body(_ data: Data) -> Self {
            .httpBody(HTTPBodySequence(data: data))
        }
    }

    public var bodyData: Data {
        get async throws {
            switch payload {
            case .httpBody(let body):
                return try await body.get()
            case .webSocket:
                return Data()
            }
        }
    }

    @available(*, unavailable, renamed: "bodyData")
    public var body: Data? {
        fatalError("use bodyData")
    }

    public init(version: HTTPVersion = .http11,
                statusCode: HTTPStatusCode,
                headers: [HTTPHeader: String] = [:],
                body: Data = Data()) {
        self.version = version
        self.statusCode = statusCode
        self.headers = headers
        self.payload = .httpBody(HTTPBodySequence(data: body))
    }

    public init(version: HTTPVersion = .http11,
                statusCode: HTTPStatusCode,
                headers: [HTTPHeader: String] = [:],
                body: HTTPBodySequence) {
        self.version = version
        self.statusCode = statusCode
        self.headers = headers
        self.payload = .httpBody(body)
    }

    public init(headers: [HTTPHeader: String] = [:],
                webSocket handler: some WSHandler) {
        self.version = .http11
        self.statusCode = .switchingProtocols
        self.headers = headers
        self.payload = .webSocket(handler)
    }
}

extension HTTPResponse {
    var shouldKeepAlive: Bool {
        headers[.connection]?.caseInsensitiveCompare("keep-alive") == .orderedSame
    }
}
