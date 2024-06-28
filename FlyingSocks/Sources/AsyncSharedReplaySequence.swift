//
//  AsyncDataSequence2.swift
//  FlyingFox
//
//  Created by Simon Whitty on 22/06/2024.
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

import Foundation

@_spi(Private)
/// AsyncSequence that can only be iterated multiple-times-concurrently.
public struct AsyncSharedReplaySequence<Base>: AsyncChunkedSequence, Sendable where Base: AsyncChunkedSequence {
    public typealias Element = Base.Element

    private let buffer: Buffer

    public init(base: Base, count: Int?) {
        self.buffer = Buffer(base: base, count: count)
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(buffer: buffer)
    }
}

public extension AsyncSharedReplaySequence {

    struct AsyncIterator: AsyncChunkedIteratorProtocol {

        private let buffer: Buffer
        private var state: State

        init(buffer: Buffer) {
            self.buffer = buffer
            self.state = .iterating(0)
        }

        enum State {
            case iterating(Int)
            case ended
        }

        public mutating func next() async throws -> Element? {
            try await nextChunk(atMost: 1)?.first
        }

        public mutating func nextChunk(count: Int) async throws -> [Element]? {
            fatalError()
        }

        public mutating func nextChunk(atMost count: Int) async throws -> [Element]? {
            switch state {
            case let .iterating(index):
                guard let chunk = try await buffer.nextChunk(from: index, atMost: count) else {
                    state = .ended
                    return nil
                }
                state = .iterating(index + chunk.count)
                return Array(chunk)
            case .ended:
                return nil
            }
        }
    }
}

extension AsyncSharedReplaySequence {

    final actor Buffer {

        var state: State
        let count: Int?

        var buffer = [Element]()

        init(base: Base, count: Int?) {
            self.state = .initial(base)
            self.count = count
        }

        enum State {
            case initial(Base)
            case iterating(Base.AsyncIterator)
            case error(any Error)
        }

        func nextChunk(from index: Int, atMost count: Int) async throws -> ArraySlice<Element>? {
            guard count > 0 else { return [] }

            if let chunk = nextBufferedChunk(from: index, atMost: count) {
                return chunk
            } else {
                return try await nextChunk(atMost: count)
            }
        }

        func nextBufferedChunk(from index: Int, atMost count: Int) -> ArraySlice<Element>? {
            guard index + 1 < buffer.endIndex else { return nil }
            let chunkEndIndex = Swift.min(index + count + 1, buffer.endIndex)
            return buffer[index..<chunkEndIndex]
        }

        func nextChunk(atMost count: Int) async throws -> ArraySlice<Element>? {
            try await withIdentifiableThrowingContinuation(isolation: self) {
                waiting[$0.id] = ($0, count)
                Task { await requestNextChunkIfRequired(atMost: count) }
            } onCancel: { id in
                Task { await cancelContinuationID(id) }
            }
        }

        typealias Continuation = IdentifiableContinuation<ArraySlice<Element>?, any Error>
        private var waiting = [Continuation.ID: (Continuation, Int)]()
        private var isRequesting = false

        private func cancelContinuationID(_ id: Continuation.ID) {
            if let continuation = waiting.removeValue(forKey: id)?.0 {
                continuation.resume(throwing: CancellationError())
            }
        }

        private func requestNextChunkIfRequired(atMost count: Int) async {
            guard !isRequesting else { return }
            isRequesting = true
            defer {
                waiting = [:]
                isRequesting = false
            }

            do {
                guard let chunk = try await requestNextChunk(atMost: count) else {
                    throw CancellationError()
                }
                buffer.append(contentsOf: chunk)
                for (continuation, count) in waiting.values {
                    let reducedChunk = chunk.prefix(upTo: Swift.min(chunk.endIndex, count))
                    continuation.resume(returning: reducedChunk)
                }
            } catch {
                for (continuation, _) in waiting.values {
                    continuation.resume(throwing: error)
                }
            }
        }

        private func requestNextChunk(atMost count: Int) async throws -> Array<Element>? {
            do {
                var iterator = try state.makeAsyncIterator()
                let chunk = try await iterator.nextChunk(atMost: count)
                state = .iterating(iterator)
                return chunk
            } catch {
                state = .error(error)
                throw error
            }
        }
    }
}

extension AsyncSharedReplaySequence.Buffer.State {

    mutating func makeAsyncIterator() throws -> Base.AsyncIterator {
        switch self {
        case let .initial(sequence):
            let iterator = sequence.makeAsyncIterator()
            self = .iterating(iterator)
            return iterator

        case let .iterating(iterator):
            return iterator

        case let .error(error):
            throw error
        }
    }
}
