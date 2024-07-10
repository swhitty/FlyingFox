//
//  AsyncChunkedSequence.swift
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

/// AsyncSequence that is able to also receive elements in chunks, instead of just one-at-a-time.
@available(*, deprecated, renamed: "AsyncBufferedSequence")
public protocol AsyncChunkedSequence<Element>: AsyncSequence where AsyncIterator: AsyncChunkedIteratorProtocol {

}

@available(*, deprecated, renamed: "AsyncBufferedIteratorProtocol")
public protocol AsyncChunkedIteratorProtocol: AsyncIteratorProtocol {

    /// Retrieves n elements from sequence in a single array.
    /// - Returns: Array with the number of elements that was requested. Or Nil.
    mutating func nextChunk(count: Int) async throws -> [Element]?
}

@available(*, unavailable, renamed: "AsyncBufferedSequence")
public protocol ChunkedAsyncSequence: AsyncSequence where AsyncIterator: ChunkedAsyncIteratorProtocol {

}

@available(*, unavailable, renamed: "AsyncBufferedIteratorProtocol")
public protocol ChunkedAsyncIteratorProtocol: AsyncIteratorProtocol {
    mutating func nextChunk(count: Int) async throws -> [Element]?
}
