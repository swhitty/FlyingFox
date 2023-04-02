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
@_spi(Private) import struct FlyingSocks.AsyncDataSequence

public struct HTTPBodySequence: Sendable, AsyncSequence {
    public typealias Element = Data

    let storage: Storage

    public init() {
        self.storage = .complete(Data())
    }

    public init(data: Data) {
        self.storage = .complete(data)
    }

    public init<S: AsyncChunkedSequence>(from bytes: S, count: Int, chunkSize: Int) where S.Element == UInt8 {
        self.storage = .sequence(AsyncDataSequence(from: bytes, count: count, chunkSize: chunkSize))
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(storage: storage)
    }

    enum Storage: @unchecked Sendable {
        case complete(Data)
        case sequence(AsyncDataSequence)
    }

    public var count: Int {
        switch storage {
        case .complete(let data):
            return data.count
        case .sequence(let sequence):
            return sequence.count
        }
    }

    func get() async throws -> Data {
        switch storage {
        case .complete(let data):
            return data
        case .sequence(let sequence):
            return try await sequence.reduce(into: Data()) {
                $0.append($1)
            }
        }
    }

    func flushIfNeeded() async throws {
        guard case .sequence(let sequence) = storage else { return }
        try await sequence.flushIfNeeded()
    }
}

public extension HTTPBodySequence {

    struct Iterator: AsyncIteratorProtocol {
        public typealias Element = Data

        private var storage: Internal
        private var isComplete: Bool = false

        fileprivate init(storage: Storage) {
            switch storage {
            case .complete(let data):
                self.storage = .complete(data)
            case .sequence(let sequence):
                self.storage = .iterator(sequence.makeAsyncIterator())
            }
        }

        public mutating func next() async throws -> Data? {
            guard !isComplete else { return nil }
            switch storage {
            case let .complete(data):
                isComplete = true
                return data
            case var .iterator(iterator):
                guard let result = try await iterator.next() else {
                    isComplete = true
                    return nil
                }
                storage = .iterator(iterator)
                return result
            }
        }

        enum Internal: @unchecked Sendable {
            case complete(Data)
            case iterator(AsyncDataSequence.AsyncIterator)
        }
    }
}
