//
//  HTTPBodySequence.swift
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
import FlyingSocks

public struct HTTPBodySequence: Sendable, AsyncSequence {
    public typealias Element = Data

    let storage: Storage

    public init() {
        self.storage = .sequence(.init(data: Data(), bufferSize: 4096))
    }

    public init(data: Data, suggestedBufferSize: Int = 4096) {
        self.storage = .sequence(.init(data: data, bufferSize: suggestedBufferSize))
    }

    public init(from bytes: some AsyncBufferedSequence<UInt8>, count: Int, suggestedBufferSize: Int = 4096) {
        self.storage = .dataSequence(
            AsyncDataSequence(from: bytes, count: count, chunkSize: suggestedBufferSize)
        )
    }

    public init(from bytes: some AsyncBufferedSequence<UInt8>, suggestedBufferSize: Int = 4096) {
        self.storage = .sequence(.init(bytes: bytes, bufferSize: suggestedBufferSize))
    }

    public init(file url: URL, suggestedBufferSize: Int = 4096) throws {
        self.storage = try .sequence(.init(fileURL: url, bufferSize: suggestedBufferSize))
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(storage: storage)
    }

    enum Storage: @unchecked Sendable {
        case dataSequence(AsyncDataSequence)
        case sequence(Sequence)

        struct Sequence {
            var sequence: any AsyncBufferedSequence<UInt8>
            var count: Int?
            var bufferSize: Int
            var canReplay: Bool

            init(data: Data, bufferSize: Int) {
                self.sequence = AsyncBufferedCollection(data)
                self.count = data.count
                self.bufferSize = bufferSize
                self.canReplay = true
            }

            init(fileURL: URL, bufferSize: Int) throws {
                self.sequence = AsyncBufferedFileSequence(contentsOf: fileURL)
                self.count =  try AsyncBufferedFileSequence.fileSize(at: fileURL)
                self.bufferSize = bufferSize
                self.canReplay = true
            }

            init(bytes: some AsyncBufferedSequence<UInt8>, bufferSize: Int) {
                self.sequence = HTTPChunkedTransferEncoder(bytes: bytes)
                self.bufferSize = bufferSize
                self.canReplay = false
            }
        }
    }

    public var count: Int? {
        switch storage {
        case .dataSequence(let sequence):
            return sequence.count
        case .sequence(let sequence):
            return sequence.count
        }
    }

    func get() async throws -> Data {
        try await reduce(into: Data()) {
            $0.append($1)
        }
    }

    func flushIfNeeded() async throws {
        guard case .dataSequence(let sequence) = storage else { return }
        try await sequence.flushIfNeeded()
    }

    var canReplay: Bool {
        switch storage {
        case .dataSequence: return false
        case .sequence(let sequence):
            return sequence.canReplay
        }
    }
}

public extension HTTPBodySequence {

    struct Iterator: AsyncIteratorProtocol {
        public typealias Element = Data

        private var storage: Internal
        private var isComplete: Bool = false
        private var bufferSize: Int = 0

        fileprivate init(storage: Storage) {
            switch storage {
            case .dataSequence(let sequence):
                self.storage = .dataIterator(sequence.makeAsyncIterator())
                self.bufferSize = 0
            case .sequence(let sequence):
                self.storage = .iterator(sequence.sequence.makeAsyncIterator())
                self.bufferSize = sequence.bufferSize
            }
        }

        public mutating func next() async throws -> Data? {
            guard !isComplete else { return nil }
            switch storage {
            case var .dataIterator(iterator):
                guard let result = try await iterator.next() else {
                    isComplete = true
                    return nil
                }
                storage = .dataIterator(iterator)
                return result
            case var .iterator(iterator):
                guard let result = try await getNextBuffer(&iterator) else {
                    isComplete = true
                    return nil
                }
                storage = .iterator(iterator)
                return result
            }
        }

        private func getNextBuffer(_ iterator: inout some AsyncBufferedIteratorProtocol<UInt8>) async throws -> Data? {
            guard let buffer = try await iterator.nextBuffer(suggested: bufferSize) else {
                return nil
            }
            return Data(buffer)
        }

        enum Internal: @unchecked Sendable {
            case dataIterator(AsyncDataSequence.AsyncIterator)
            case iterator(any AsyncBufferedIteratorProtocol<UInt8>)
        }
    }
}
