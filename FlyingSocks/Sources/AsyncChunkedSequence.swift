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
public protocol AsyncChunkedSequence<Element>: AsyncSequence, Sendable where AsyncIterator: AsyncChunkedIteratorProtocol {

}

public protocol AsyncChunkedIteratorProtocol: AsyncIteratorProtocol {

    /// Retrieves n elements from sequence in a single array.
    /// - Returns: Array with the number of elements that was requested. Or Nil.
    /// ** Soft Deprecated ** Implement  `nextChunk(atMost:)`
    mutating func nextChunk(count: Int) async throws -> [Element]?

    /// Retrieve up to n elements from sequence in a single array.
    /// - Parameter count: The maximum number of elements to retrieve if possible.
    /// - Returns: Array with number of elements less than or equal to count. Or Nil if sequence has ended.
    mutating func nextChunk(atMost count: Int) async throws -> [Element]?
}

public extension AsyncChunkedIteratorProtocol {

    mutating func next() async throws -> Element? {
        try await nextChunk(count: 1)?.first
    }

    /// Default implementation for compatibility with existing conformance. Will be removed in a future release.
    /// - Parameter count: The number of elements to retrieve if possible.
    /// - Returns: Array with number of elements less than or equal to count. Or Nil if sequence has ended.
    mutating func nextChunk(atMost count: Int) async throws -> [Element]? {
        try await Private.$didImplementAtMost.withValue(false) {
            try await nextChunk(count: count)
        }
    }

    mutating func nextChunk(count: Int) async throws -> [Element]? {
        // Default implementations are provided for both methods, but one must be implemented.
        if !Private.didImplementAtMost {
            print("Private.didImplementAtMost")
        }
        precondition(Private.didImplementAtMost, "requires implementation nextChunk(atMost:)")
        guard count > 0 else { return [] }

        var buffer = [Element]()
        while buffer.count < count {
            try Task.checkCancellation()
            let remaining = count - buffer.count
            if let chunk = try await nextChunk(atMost: remaining) {
                buffer.append(contentsOf: chunk)
            } else {
                throw SocketError.disconnected
            }
        }
        return buffer
    }
}

private enum Private {
    @TaskLocal static var didImplementAtMost: Bool = true
}

@available(*, unavailable, renamed: "AsyncChunkedSequence")
public protocol ChunkedAsyncSequence: AsyncSequence where AsyncIterator: ChunkedAsyncIteratorProtocol {

}

@available(*, unavailable, renamed: "AsyncChunkedIteratorProtocol")
public protocol ChunkedAsyncIteratorProtocol: AsyncIteratorProtocol {
    mutating func nextChunk(count: Int) async throws -> [Element]?
}
