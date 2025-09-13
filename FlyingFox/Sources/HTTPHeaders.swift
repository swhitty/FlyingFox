//
//  HTTPHeaders.swift
//  FlyingFox
//
//  Created by Simon Whitty on 13/09/2025.
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

public struct HTTPHeaders: Hashable, Sendable, Sequence, ExpressibleByDictionaryLiteral {
    var storage: [HTTPHeader: [String]] = [:]

    public init() { }

    public init(_ headers: [HTTPHeader: String]) {
        self.storage = headers.mapValues { [$0] }
    }

    public init(dictionaryLiteral elements: (HTTPHeader, String)...) {
        for (header, value) in elements {
            if HTTPHeaders.canCombineValues(for: header) {
                let values = value
                    .split(separator: ",", omittingEmptySubsequences: true)
                    .map { String($0.trimmingCharacters(in: .whitespaces)) }
                storage[header, default: []].append(contentsOf: values)
            } else {
                storage[header, default: []].append(value)
            }
        }
    }

    public subscript(header: HTTPHeader) -> String? {
        get {
            guard let values = storage[header] else { return nil }
            if HTTPHeaders.canCombineValues(for: header) {
                return values.joined(separator: ", ")
            } else {
                return values.first
            }
        }
        set {
            if let newValue {
                if storage[header] != nil {
                    storage[header]?[0] = newValue
                } else {
                    storage[header] = [newValue]
                }
            } else {
                storage.removeValue(forKey: header)
            }
        }
    }

    public var keys: some Collection<HTTPHeader> {
        storage.keys
    }

    public var values: some Collection<[String]> {
        storage.values
    }

    public func values(for header: HTTPHeader) -> [String] {
        storage[header] ?? []
    }

    public mutating func addValue(_ value: String, for header: HTTPHeader) {
        storage[header, default: []].append(value)
    }

    public mutating func setValues(_ values: [String], for header: HTTPHeader) {
        storage[header] = values
    }

    public mutating func removeValue(_ header: HTTPHeader) {
        storage.removeValue(forKey: header)
    }

    public func makeIterator() -> some IteratorProtocol<(key: HTTPHeader, value: String)> {
        storage.lazy
            .flatMap { (key, values) in values.lazy.map { (key, $0) } }
            .makeIterator()
    }
}

package extension HTTPHeaders {

    private static let singleValueHeaders: Set<HTTPHeader> = [
        .cookie, .setCookie, .date, .eTag, .contentLength, .contentType, .authorization, .host
    ]

    static func canCombineValues(for header: HTTPHeader) -> Bool {
        !singleValueHeaders.contains(header)
    }
}
