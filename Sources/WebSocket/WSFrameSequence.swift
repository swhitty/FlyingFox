//
//  WSFrameSequence.swift
//  FlyingFox
//
//  Created by Simon Whitty on 18/03/2022.
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

// some AsyncSequence<WSFrame>
public struct WSFrameSequence: AsyncSequence, AsyncIteratorProtocol {
    public typealias Element = WSFrame

    private let inner: AnyAsyncSequence<WSFrame>

    public init<S: AsyncSequence>(_ sequence: S) where S.Element == WSFrame {
        self.inner = AnyAsyncSequence(sequence)
    }

    init<S: ChunkedAsyncSequence>(_ sequence: S) where S.Element == UInt8 {
        self.init(DecodeFrameSequence(bytes: sequence))
    }

    public func makeAsyncIterator() -> Self {
        self
    }

    public mutating func next() async throws -> WSFrame? {
        var iterator = inner.makeAsyncIterator()
        return try await iterator.next()
    }
}

private struct DecodeFrameSequence<S: ChunkedAsyncSequence>: AsyncSequence, AsyncIteratorProtocol where S.Element == UInt8 {
    typealias Element = WSFrame
    let bytes: S

    func makeAsyncIterator() -> Self {
        self
    }

    public mutating func next() async throws -> WSFrame? {
        do {
            return try await WSFrameEncoder.decodeFrame(from: bytes)
        } catch SocketError.disconnected, is SequenceTerminationError {
            return nil
        } catch {
            throw error
        }
    }
}
