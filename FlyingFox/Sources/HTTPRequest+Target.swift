//
//  HTTPRequest+Target.swift
//  FlyingFox
//
//  Created by Simon Whitty on 08/11/2025.
//  Copyright © 2025 Simon Whitty. All rights reserved.
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

public extension HTTPRequest {

    // RFC9112: e.g. /a%2Fb?q=1
    struct Target: Sendable, Equatable {

        // raw percent encoded path e.g. /fish%20chips
        private var _path: String

        // raw percent encoded query string e.g. q=fish%26chips&qty=15
        private var _query: String

        public init(path: String, query: String) {
            self._path = path
            self._query = query
        }

        public func path(percentEncoded: Bool = true) -> String {
            guard percentEncoded else {
                return _path.removingPercentEncoding ?? _path
            }
            return _path
        }

        public func query(percentEncoded: Bool = true) -> String {
            guard percentEncoded else {
                return _query.removingPercentEncoding ?? _query
            }
            return _query
        }

        public var rawValue: String {
            guard !_query.isEmpty else {
                return _path
            }
            return "\(_path)?\(_query)"
        }
    }
}
