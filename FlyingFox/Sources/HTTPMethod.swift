//
//  HTTPMethod.swift
//  FlyingFox
//
//  Created by Simon Whitty on 17/02/2022.
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

public struct HTTPMethod: Sendable, RawRepresentable, Hashable, ExpressibleByStringLiteral {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.init(rawValue: rawValue.uppercased())
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value.uppercased())
    }
}

public extension HTTPMethod {
    func hash(into hasher: inout Hasher) {
        rawValue.uppercased().hash(into: &hasher)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue.uppercased() == rhs.rawValue.uppercased()
    }
}

public extension HTTPMethod {
    internal static let sortedMethods = [
        HTTPMethod.GET,
        .POST,
        .PUT,
        .DELETE,
        .PATCH,
        .HEAD,
        .OPTIONS,
        .CONNECT,
        .TRACE
    ]

    static let allMethods = Set(HTTPMethod.sortedMethods)

    static let GET     = HTTPMethod("GET")
    static let POST    = HTTPMethod("POST")
    static let PUT     = HTTPMethod("PUT")
    static let DELETE  = HTTPMethod("DELETE")
    static let PATCH   = HTTPMethod("PATCH")
    static let HEAD    = HTTPMethod("HEAD")
    static let OPTIONS = HTTPMethod("OPTIONS")
    static let CONNECT = HTTPMethod("CONNECT")
    static let TRACE   = HTTPMethod("TRACE")
}

public extension Set<HTTPMethod> {

    /// Comma delimited string of methods, sorted to ensure default methods appear first.
    var stringValue: String {
        var sortedMethods = HTTPMethod
            .sortedMethods
            .filter { contains($0) }

        sortedMethods.append(contentsOf: self.filter { !HTTPMethod.allMethods.contains($0) })
        return sortedMethods.map(\.rawValue).joined(separator: ",")
    }
}
