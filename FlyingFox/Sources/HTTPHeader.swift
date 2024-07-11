//
//  HTTPHeader.swift
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

public struct HTTPHeader: Sendable, RawRepresentable, Hashable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    public func hash(into hasher: inout Hasher) {
        rawValue.lowercased().hash(into: &hasher)
    }

    public static func == (lhs: HTTPHeader, rhs: HTTPHeader) -> Bool {
        lhs.rawValue.caseInsensitiveCompare(rhs.rawValue) == .orderedSame
    }
}

public extension HTTPHeader {
    static let authorization    = HTTPHeader("Authorization")
    static let connection       = HTTPHeader("Connection")
    static let contentLength    = HTTPHeader("Content-Length")
    static let contentType      = HTTPHeader("Content-Type")
    static let contentEncoding  = HTTPHeader("Content-Encoding")
    static let host             = HTTPHeader("Host")
    static let location         = HTTPHeader("Location")
    static let webSocketAccept  = HTTPHeader("Sec-WebSocket-Accept")
    static let webSocketKey     = HTTPHeader("Sec-WebSocket-Key")
    static let webSocketVersion = HTTPHeader("Sec-WebSocket-Version")
    static let transferEncoding = HTTPHeader("Transfer-Encoding")
    static let upgrade          = HTTPHeader("Upgrade")
}

public extension [HTTPHeader: String] {

    func values(for header: HTTPHeader) -> [String] {
        let value = self[header] ?? ""
        return value
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { String($0.trimmingCharacters(in: .whitespaces)) }
    }

    mutating func setValues(_ values: [String], for header: HTTPHeader) {
        self[header] = values.joined(separator: ", ")
    }

    mutating func addValue(_ value: String, for header: HTTPHeader) {
        setValues(values(for: header) + [value], for: header)
    }
}
