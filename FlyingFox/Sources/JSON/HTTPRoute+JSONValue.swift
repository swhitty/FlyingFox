//
//  HTTPRoute+JSONValue.swift
//  FlyingFox
//
//  Created by Simon Whitty on 15/08/2024.
//  Copyright © 2024 Simon Whitty. All rights reserved.
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

public extension HTTPRoute {

    /// Create a route to a request with a JSON body matching the supplued predicate.
    /// - Parameters:
    ///   - string: String representing the method, path and query parameters of the route `POST /fish`
    ///   - headers: Headers to evaluate and match
    ///   - predicate: Predicate to evaluate body of the request via a `JSONValue`
    init(
        _ string: String,
        headers: [HTTPHeader: String] = [:],
        jsonBody predicate: @escaping @Sendable (JSONValue) throws -> Bool
    ) {
        self.init(string, headers: headers, body: .jsonValue(where: predicate))
    }
}
