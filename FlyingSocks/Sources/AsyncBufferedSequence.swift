//
//  AsyncBufferedSequence.swift
//  FlyingFox
//
//  Created by Simon Whitty on 06/07/2024.
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

/// AsyncSequence that is buffered and can optionally receive contiguous elements in chunks, instead of just one-at-a-time.
public protocol AsyncBufferedSequence<Element>: AsyncSequence where AsyncIterator: AsyncBufferedIteratorProtocol {

}

public protocol AsyncBufferedIteratorProtocol<Element>: AsyncIteratorProtocol {
    // Buffered elements are returned in this collection type
    associatedtype Buffer: Collection where Buffer.Element == Element

    /// Retrieves available elements from the buffer. Suspends if 0 elements are available.
    /// - Parameter count: The maximum number of elements to return
    /// - Returns: Collection with between 1 and the number elements that was requested. Nil is returned if the sequence has ended.
    mutating func nextBuffer(atMost count: Int) async throws -> Buffer?
}

public extension AsyncBufferedIteratorProtocol {

    /// Retrieves n elements from sequence in a single array.
    /// - Parameter count: The maximum number of elements to return
    /// - Returns: Array with the number of elements that was requested. Nil is returned if the sequence has ended.
    mutating func nextBuffer(count: Int) async throws -> [Element]? {
        guard count > 0 else { return [] }

        var buffer = [Element]()
        while buffer.count < count {
            try Task.checkCancellation()
            let remaining = count - buffer.count
            if let chunk = try await nextBuffer(atMost: remaining) {
                buffer.append(contentsOf: chunk)
            } else {
                throw SocketError.disconnected
            }
        }
        return buffer.isEmpty ? nil : buffer
    }
}
