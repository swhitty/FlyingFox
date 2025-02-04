//
//  AsyncBufferedPrefixSequence.swift
//  FlyingFox
//
//  Created by Simon Whitty on 04/02/2025.
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

package struct AsyncBufferedPrefixSequence<Base: AsyncBufferedSequence>: AsyncBufferedSequence {
    package typealias Element = Base.Element

    private let base: Base
    private let count: Int
    
    package init(base: Base, count: Int) {
        self.base = base
        self.count = count
    }

    package func makeAsyncIterator() -> Iterator {
        Iterator(iterator: base.makeAsyncIterator(), remaining: count)
    }

    package struct Iterator: AsyncBufferedIteratorProtocol {
        private var iterator: Base.AsyncIterator
        private var remaining: Int

        init (iterator: Base.AsyncIterator, remaining: Int) {
            self.iterator = iterator
            self.remaining = remaining
        }

        package mutating func next() async throws -> Base.Element? {
            guard remaining > 0 else { return nil }

            if let element = try await iterator.next() {
                remaining -= 1
                return element
            } else {
                remaining = 0
                return nil
            }
        }

        package mutating func nextBuffer(suggested count: Int) async throws -> Base.AsyncIterator.Buffer? {
            guard remaining > 0 else { return nil }

            let count = Swift.min(remaining, count)
            if let buffer = try await iterator.nextBuffer(suggested: count) {
                remaining -= buffer.count
                return buffer
            } else {
                remaining = 0
                return nil
            }
        }
    }
}
