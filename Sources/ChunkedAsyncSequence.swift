//
//  ChunkedAsyncSequence.swift
//  FlyingFox
//
//  Created by Simon Whitty on 20/02/2022.
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

protocol ChuckedAsyncSequence: AsyncSequence {

    /// Retrieve next n elements can be requested from an AsyncSequence.
    /// - Parameter count: Number of elements to be read from the sequence
    /// - Returns: Returns all the requested number or elements or nil when the
    /// sequence ends before all of requested elements are retrieved.
    func next(count: Int) async throws -> [Element]?
}

extension ChuckedAsyncSequence {

    /// Default implementation that does not read elements in chunks, but slowly
    /// reads the chunk one element at a time.
    func next(count: Int) async throws -> [Element]? {
        var buffer = [Element]()
        var iterator = makeAsyncIterator()

        while buffer.count < count,
              let element = try await iterator.next() {
            buffer.append(element)
        }

        return buffer.count == count ? buffer : nil
    }
}
