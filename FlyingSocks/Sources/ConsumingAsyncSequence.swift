//
//  ConsumingAsyncSequence.swift
//  FlyingFox
//
//  Created by Simon Whitty on 17/02/2022.
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

package struct ConsumingAsyncSequence<Base: AsyncBufferedSequence>: AsyncBufferedSequence {
    package typealias Element = Base.Element

    private let buffer: SharedBuffer

    package init<C: Collection>(_ collection: C) where Base == AsyncBufferedCollection<C>  {
        self.buffer = SharedBuffer(AsyncBufferedCollection(collection))
    }

    package init(bytes: [UInt8]) where Base == AsyncBufferedCollection<[UInt8]>  {
        self.init(bytes)
    }

    package func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(buffer: buffer)
    }

    package var index: Int { buffer.index ?? 0 }

    package struct AsyncIterator: AsyncBufferedIteratorProtocol {

        let buffer: SharedBuffer
        var hasStarted = false

        package mutating func next() async throws -> Element? {
            return try await buffer.next()
        }

        package mutating func nextBuffer(suggested count: Int) async throws -> Base.AsyncIterator.Buffer? {
            return try await buffer.nextBuffer(suggested: count)
        }
    }
}

extension ConsumingAsyncSequence {

    final class SharedBuffer: @unchecked Sendable {

        private(set) var state: Mutex<State>

        init(_ sequence: Base) {
            self.state = Mutex(.initial(sequence))
        }

        enum State: @unchecked Sendable {
            case initial(Base)
            case iterating(Base.AsyncIterator, index: Int)
        }

        var index: Int? {
            switch state.copy() {
            case .initial:
                return nil
            case .iterating(_, index: let index):
                return index
            }
        }

        func next() async throws -> Element? {
            var (iterator, index) = try state.withLock { try $0.makeAsyncIterator() }
            guard let element = try await iterator.next() else {
                return nil
            }
            setState(.iterating(iterator, index: index + 1))
            return element
        }

        func nextBuffer(suggested count: Int) async throws -> Base.AsyncIterator.Buffer? {
            var (iterator, index) = try state.withLock { try $0.makeAsyncIterator() }
            guard let buffer = try await iterator.nextBuffer(suggested: count) else {
                return nil
            }
            setState(.iterating(iterator, index: index + buffer.count))
            return buffer
        }

        func setState(_ state: State) {
            self.state.withLock { $0 = state }
        }
    }
}

extension ConsumingAsyncSequence.SharedBuffer.State {

    mutating func makeAsyncIterator() throws -> (Base.AsyncIterator, Int) {
        switch self {
        case let .initial(sequence):
            let iterator = sequence.makeAsyncIterator()
            self = .iterating(iterator, index: 0)
            return (iterator, 0)

        case let .iterating(iterator, index):
            return (iterator, index)
        }
    }
}
