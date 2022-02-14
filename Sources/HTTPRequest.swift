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

public struct HTTPRequest {
    public var method: HTTPMethod
    public var version: HTTPVersion
    public var path: String
    public var query: [(name: String, value: String)]
    public var headers: [HTTPHeader: String]
    public var body: Data
}

public struct HTTPMethod: RawRepresentable, Hashable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension HTTPMethod {
    static let GET     = HTTPMethod(rawValue: "GET")
    static let POST    = HTTPMethod(rawValue: "POST")
    static let PUT     = HTTPMethod(rawValue: "PUT")
    static let DELETE  = HTTPMethod(rawValue: "DELETE")
    static let PATCH   = HTTPMethod(rawValue: "PATCH")
    static let HEAD    = HTTPMethod(rawValue: "HEAD")
    static let OPTIONS = HTTPMethod(rawValue: "OPTIONS")
    static let CONNECT = HTTPMethod(rawValue: "CONNECT")
    static let TRACE   = HTTPMethod(rawValue: "TRACE")
}

extension HTTPRequest {
    var shouldKeepAlive: Bool {
        headers[.connection]?.caseInsensitiveCompare("keep-alive") == .orderedSame
    }
}
