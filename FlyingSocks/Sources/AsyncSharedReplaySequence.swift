//
//  AsyncSharedReplaySequence.swift
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

/// AsyncSequence that can only be iterated multiple-times-concurrently.
package struct AsyncSharedReplaySequence<Base>: AsyncBufferedSequence, Sendable where Base: AsyncBufferedSequence {
    package typealias Element = Base.Element

    private let buffer: SharedBuffer

    package init(base: Base, count: Int?) {
        self.buffer = SharedBuffer(base: base, count: count)
    }

    package func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(buffer: buffer)
    }
}

package extension AsyncSharedReplaySequence {

    struct AsyncIterator: AsyncBufferedIteratorProtocol {
        package typealias Buffer = ArraySlice<Element>

        private let buffer: SharedBuffer
        private var state: State

        init(buffer: SharedBuffer) {
            self.buffer = buffer
            self.state = .iterating(0)
        }

        enum State {
            case iterating(Int)
            case ended
        }

        package mutating func next() async throws -> Element? {
            try await nextBuffer(suggested: 1)?.first
        }

        package mutating func nextBuffer(suggested count: Int) async throws -> ArraySlice<Element>? {
            switch state {
            case let .iterating(index):
                guard let chunk = try await buffer.nextChunk(from: index, atMost: count) else {
                    state = .ended
                    return nil
                }
                state = .iterating(index + chunk.count)
                return chunk
            case .ended:
                return nil
            }
        }
    }
}

extension AsyncSharedReplaySequence {

    final actor SharedBuffer {

        var state: State
        let bufferCount: Int?

        var buffer = [Element]()

        init(base: Base, count: Int?) {
            self.state = .initial(base)
            self.bufferCount = count
        }

        enum State {
            case initial(Base)
            case iterating(Base.AsyncIterator)
            case error(any Error)
        }

        func nextChunk(from index: Int, atMost count: Int) async throws -> ArraySlice<Element>? {
            guard count > 0 else {
                return []
            }

            if let chunk = nextBufferedChunk(from: index, atMost: count) {
                return chunk
            } else {
                if let bufferCount {
                    let remaining = bufferCount - index
                    guard remaining > 0 else { return nil }
                    return try await nextChunk(atMost: Swift.min(count, remaining))

                } else {
                    return try await nextChunk(atMost: count)
                }

            }
        }

        func nextBufferedChunk(from index: Int, atMost count: Int) -> ArraySlice<Element>? {
            guard index < buffer.endIndex else {
                return nil
            }
            let chunkEndIndex = Swift.min(index + count, buffer.endIndex)
            return buffer[index..<chunkEndIndex]
        }

        func nextChunk(atMost count: Int) async throws -> ArraySlice<Element>? {
            try await withIdentifiableThrowingContinuation(isolation: self) {
                appendContinuatation($0, count: count)
            } onCancel: { id in
                Task { await cancelContinuationID(id) }
            }
        }

        private func appendContinuatation(_ continuation: Continuation, count: Int) {
            waiting[continuation.id] = (continuation, count)
            Task { await requestNextChunkIfRequired(atMost: count) }
        }

        typealias Continuation = IdentifiableContinuation<ArraySlice<Element>?, any Error>
        private var waiting = [Continuation.ID: (Continuation, Int)]()
        private var isRequesting = false

        private func cancelContinuationID(_ id: Continuation.ID) {
            if let continuation = waiting.removeValue(forKey: id)?.0 {
                continuation.resume(returning: nil)
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
                    throw SocketError.disconnected
                }
                let startIndex = buffer.endIndex
                buffer.append(contentsOf: chunk)
                for (continuation, count) in waiting.values {
                    let endIndex = buffer.index(startIndex, offsetBy: count, limitedBy: buffer.endIndex) ?? buffer.endIndex
                    let reducedChunk = buffer[startIndex..<endIndex]
                    continuation.resume(returning: reducedChunk)
                }
            } catch {
                if let bufferCount, buffer.count != bufferCount {
                    for (continuation, _) in waiting.values {
                        continuation.resume(throwing: error)
                    }
                } else {
                    for (continuation, _) in waiting.values {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }

        private func requestNextChunk(atMost count: Int) async throws -> (some Collection<Element>)? {
            do {
                var iterator = try Transferring(state.makeAsyncIterator())
                let chunk = try await iterator.nextBuffer(suggested: count)?.value
                state = .iterating(iterator.value)
                return chunk
            } catch {
                state = .error(error)
                throw error
            }
        }
    }
}

private extension Transferring where Value: AsyncBufferedIteratorProtocol {

    mutating func nextBuffer(suggested count: Int) async throws -> Transferring<Value.Buffer>? {
        guard let buffer = try await value.nextBuffer(suggested: count) else { return nil }
        return Transferring<Value.Buffer>(buffer)
    }
}

extension AsyncSharedReplaySequence.SharedBuffer.State {

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

package protocol Flushable {
    func flushIfNeeded() async throws
}

extension AsyncSharedReplaySequence: Flushable {
    package func flushIfNeeded() async throws {
        try await buffer.flushIfNeeded()
    }
}

private extension AsyncSharedReplaySequence.SharedBuffer {
    func flushIfNeeded() async throws {
        guard let bufferCount else { return }

        while buffer.count < bufferCount {
            _ = try await nextChunk(atMost: 4096)
        }
    }
}
