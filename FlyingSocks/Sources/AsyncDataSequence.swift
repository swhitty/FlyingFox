//
//  AsyncDataSequence.swift
//  FlyingFox
//
//  Created by Simon Whitty on 02/04/2023.
//  Copyright © 2023 Simon Whitty. All rights reserved.
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

@_spi(Private)
/// AsyncSequence that can only be iterated one-time-only. Suitable for large data sizes.
public struct AsyncDataSequence: AsyncSequence, Sendable {
    public typealias Element = Data

    private let loader: DataLoader

    public init<S: AsyncChunkedSequence>(from bytes: S, count: Int, chunkSize: Int) where S.Element == UInt8 {
        self.loader = DataLoader(
            count: count,
            chunkSize: chunkSize,
            iterator: bytes.makeAsyncIterator()
        )
    }

    public var count: Int { loader.count }

    public func makeAsyncIterator() -> Iterator {
        Iterator(loader: loader)
    }

    public struct Iterator: AsyncIteratorProtocol {
        public typealias Element = Data

        private let loader: DataLoader

        private var index: Int = 0

        fileprivate init(loader: DataLoader) {
            self.loader = loader
        }

        public mutating func next() async throws -> Data? {
            let data = try await loader.nextData(from: index)
            if let data = data {
                index += data.count
            }
            return data
        }
    }
}



private extension AsyncDataSequence {

    actor DataLoader {
        nonisolated fileprivate let count: Int
        nonisolated fileprivate let chunkSize: Int
        private let iterator: AnyChunkedIterator
        private var state: State

        init<I: AsyncChunkedIteratorProtocol>(count: Int, chunkSize: Int, iterator: I) where I.Element == UInt8 {
            self.count = count
            self.chunkSize = chunkSize
            self.iterator = ChunkedIterator(iterator)
            self.state = .ready(index: 0)
        }

        func nextData(from current: Int) async throws -> Data? {
            guard case .ready(let index) = state, index == current else {
                throw Error.unexpectedState
            }
            state = .fetching

            let endIndex = Swift.min(count, index + chunkSize)
            let nextCount = endIndex - index
            guard nextCount > 0 else {
                state = .complete
                return nil
            }

            do {
                guard let element = try await iterator.nextChunk(count: nextCount) else {
                    throw Error.unexpectedEOF
                }
                state = .ready(index: endIndex)
                return Data(element)
            } catch {
                state = .complete
                throw error
            }
        }

        enum State {
            case ready(index: Int)
            case fetching
            case complete
        }

        enum Error: Swift.Error {
            case unexpectedState
            case unexpectedEOF
        }
    }

    private class AnyChunkedIterator: AsyncChunkedIteratorProtocol {
        func next() async throws -> UInt8? { fatalError("Method must be overridden") }
        func nextChunk(count: Int) async throws -> [UInt8]? { fatalError("Method must be overridden") }
    }

    private final class ChunkedIterator<Base: AsyncChunkedIteratorProtocol>: AnyChunkedIterator where Base.Element == UInt8 {
        private var base: Base

        init(_ base: Base) {
            self.base = base
        }

        override func next() async throws -> Element? {
            try await base.next()
        }

        override func nextChunk(count: Int) async throws -> [UInt8]? {
            try await base.nextChunk(count: count)
        }
    }
}
