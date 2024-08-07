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
    func collectUntil(buffer: @escaping ([Element]) -> Bool) -> CollectUntil<Self> {
        CollectUntil(self, until: buffer)
    }

    func takeNext() async throws -> Element {
        var iterator = makeAsyncIterator()
        guard let line = try await iterator.next() else {
            throw SequenceTerminationError()
        }
        return line
    }
}

struct SequenceTerminationError: LocalizedError {
    var errorDescription: String? = "Sequence Terminated"
}

struct CollectUntil<Base: AsyncSequence>: AsyncSequence {
    typealias Element = [Base.Element]
    typealias Predicate = ([Base.Element]) -> Bool

    let base: Base
    let until: Predicate

    init(_ base: Base, until: @escaping Predicate) {
        self.base = base
        self.until = until
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: base.makeAsyncIterator(), until: until)
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        var iterator: Base.AsyncIterator
        var until: Predicate

        mutating func next() async throws -> Element? {
            var buffer = Element()

            while let element = try await iterator.next() {
                buffer.append(element)
                guard !until(buffer) else {
                    break
                }
            }

            return buffer.isEmpty ? nil : buffer
        }
    }
}

extension AsyncSequence where Element == UInt8 {

    // some AsyncSequence<String>
    func collectStrings(separatedBy string: String) -> AsyncThrowingMapSequence<CollectUntil<Self>, String> {
        let bytes = Array(string.data(using: .utf8)!)
        let buffer = collectUntil(buffer: { $0.suffix(bytes.count) == bytes })
        return buffer.map {
            let chars = ($0.suffix(bytes.count) == bytes) ? $0.dropLast(bytes.count) : $0
            guard let string = String(bytes: chars, encoding: .utf8) else {
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
