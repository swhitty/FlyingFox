//
//  AsyncSequence+Extensions.swift
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

extension AsyncSequence {
    func collectUntil(element: @escaping (Element) -> Bool) -> CollectUntil<Self> {
        CollectUntil(sequence: self, until: element)
    }

    func collectUntil(buffer: @escaping ([Element]) -> Bool) -> CollectUntil<Self> {
        CollectUntil(sequence: self, until: buffer)
    }

    func first() async throws -> Element {
        guard let next = try await first(where: { _ in true }) else {
            throw AsyncSequenceError("Premature termination")
        }
        return next
    }
}

struct ClosureSequence<Element>: AsyncSequence, AsyncIteratorProtocol {
    let closure: () async throws -> Element

    func makeAsyncIterator() -> ClosureSequence<Element> { self }

    mutating func next() async throws -> Element? {
        try await closure()
    }
}

struct CollectUntil<S>: AsyncSequence, AsyncIteratorProtocol where S: AsyncSequence {
    typealias Element = [S.Element]
    let sequence: S

    let until: ([S.Element]) -> Bool

    init(sequence: S, until: @escaping (S.Element) -> Bool) {
        self.sequence = sequence
        self.until = { until($0.last!) }
    }

    init(sequence: S, until: @escaping ([S.Element]) -> Bool) {
        self.sequence = sequence
        self.until = until
    }

    func makeAsyncIterator() -> Self { self }

    mutating func next() async throws -> [S.Element]? {
        var buffer = [S.Element]()

        for try await element in sequence {
            buffer.append(element)
            guard !until(buffer) else {
                break
            }
        }
        return buffer
    }
}

extension AsyncSequence where Element == UInt8 {

    // some AsyncSequence<String>
    func collectStrings(separatedBy string: String) -> AsyncThrowingMapSequence<CollectUntil<Self>, String> {
        let bytes = Array(string.data(using: .utf8)!)
        let buffer = collectUntil(buffer: { $0.suffix(bytes.count) == bytes })
        return buffer.map {
            guard let string = String(bytes: $0.dropLast(bytes.count), encoding: .utf8) else {
                throw AsyncSequenceError("Invalid String Conversion")
            }
            return string
        }
    }
}

struct AsyncSequenceError: LocalizedError {
    var errorDescription: String?

    init(_ description: String) {
        self.errorDescription = description
    }
}
