//
//  HTTPRequest.swift
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

public struct HTTPRequest: Sendable {
    public var method: HTTPMethod
    public var version: HTTPVersion
    public var path: String
    public var query: [QueryItem]
    public var headers: [HTTPHeader: String]
    public var bodySequence: HTTPBodySequence

    @TaskLocal static var matchedRoute: HTTPRoute?

    public var bodyData: Data {
        get async throws {
            try await bodySequence.get()
        }
    }

    public mutating func setBodyData(_ data: Data) {
        bodySequence = HTTPBodySequence(data: data)
    }

    @available(*, unavailable, renamed: "bodyData")
    public var body: Data {
        get { fatalError("unavailable") }
        set { fatalError("unavailable") }
    }

    public init(method: HTTPMethod,
                version: HTTPVersion,
                path: String,
                query: [QueryItem],
                headers: [HTTPHeader: String],
                body: HTTPBodySequence) {
        self.method = method
        self.version = version
        self.path = path
        self.query = query
        self.headers = headers
        self.bodySequence = body
    }

    public init(method: HTTPMethod,
                version: HTTPVersion,
                path: String,
                query: [QueryItem],
                headers: [HTTPHeader: String],
                body: Data) {
        self.method = method
        self.version = version
        self.path = path
        self.query = query
        self.headers = headers
        self.bodySequence = HTTPBodySequence(data: body)
    }
}

extension HTTPRequest {
    var shouldKeepAlive: Bool {
        headers[.connection]?.caseInsensitiveCompare("keep-alive") == .orderedSame
    }

    public func pathParameter(for identifier: String) -> String? {
        let components = path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { String($0) }

        guard
            components.isEmpty == false,
            let parameterIndex = Self.matchedRoute?.pathParameters[identifier],
            components.count < parameterIndex
        else {
            return nil
        }

        return components[parameterIndex]
    }
}
