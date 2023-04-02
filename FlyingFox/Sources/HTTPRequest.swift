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

    public var bodyData: Data {
        get async throws {
            try await bodySequence.get()
        }
    }

    public mutating func setBodyData(_ data: Data) {
        bodySequence = HTTPBodySequence(data: data)
    }

    @available(*, deprecated, renamed: "bodyData")
    public var body: Data {
        get {
            guard case .complete(let data) = bodySequence.storage else {
                preconditionFailure("Body is too large for synchronous accessor. Iterate using HTTPBodySequence")
            }
            return data
        }
        set { setBodyData(newValue) }
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

@available(*, deprecated, message: "HTTPRequest will soon remove conformance to Equatable")
extension HTTPRequest: Equatable {

    public static func == (lhs: HTTPRequest, rhs: HTTPRequest) -> Bool {
        guard case .complete(let lhsBody) = lhs.bodySequence.storage,
              case .complete(let rhsBody) = rhs.bodySequence.storage else {
            return false
        }
        return lhs.method == rhs.method &&
               lhs.version == rhs.version &&
               lhs.path == rhs.path &&
               lhs.query == rhs.query &&
               lhs.headers == rhs.headers &&
               lhsBody == rhsBody
    }
}

extension HTTPRequest {
    var shouldKeepAlive: Bool {
        headers[.connection]?.caseInsensitiveCompare("keep-alive") == .orderedSame
    }
}
