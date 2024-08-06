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
        self.storage = Storage(data: Data(), bufferSize: 4096)
    }

    public init(data: Data, suggestedBufferSize: Int = 4096) {
        self.storage = Storage(data: data, bufferSize: suggestedBufferSize)
    }

    public init(from bytes: some AsyncBufferedSequence<UInt8>, count: Int, suggestedBufferSize: Int = 4096) {
        self.storage = Storage(
            bytes: bytes,
            count: count,
            bufferSize: suggestedBufferSize
        )
    }

    public init(shared bytes: some AsyncBufferedSequence<UInt8>, count: Int, suggestedBufferSize: Int = 4096) {
        self.storage = Storage(
            shared: bytes,
            count: count,
            bufferSize: suggestedBufferSize
        )
    }

    public init(from bytes: some AsyncBufferedSequence<UInt8>, suggestedBufferSize: Int = 4096) {
        self.storage = Storage(
            bytes: HTTPChunkedTransferEncoder(bytes: bytes),
            count: nil,
            bufferSize: suggestedBufferSize
        )
    }

    public init(file url: URL, suggestedBufferSize: Int = 4096) throws {
        self.storage = try Storage(fileURL: url, bufferSize: suggestedBufferSize)
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(storage: storage)
    }

    struct Storage: @unchecked Sendable {
        var sequence: any AsyncBufferedSequence<UInt8>
        var count: Int?
        var bufferSize: Int
        var flusher: (any Flushable)?
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

        init(bytes: some AsyncBufferedSequence<UInt8>,
             count: Int?,
             bufferSize: Int,
             canReplay: Bool = false) {
            self.sequence = bytes
            self.count = count
            self.bufferSize = bufferSize
            self.canReplay = canReplay
        }

        init(shared bytes: some AsyncBufferedSequence<UInt8>,
             count: Int,
             bufferSize: Int) {
            let shared = AsyncSharedReplaySequence(base: bytes, count: count)
            self.sequence = shared
            self.count = count
            self.flusher = shared
            self.bufferSize = bufferSize
            self.canReplay = true
        }
    }

    public var count: Int? {
        storage.count
    }

    func get() async throws -> Data {
        try await reduce(into: Data()) {
            $0.append($1)
        }
    }

    func flushIfNeeded() async throws {
        try await storage.flusher?.flushIfNeeded()
    }

    var canReplay: Bool {
        storage.canReplay
    }
}

public extension HTTPBodySequence {

    struct Iterator: AsyncIteratorProtocol {
        public typealias Element = Data

        private var iterator: any AsyncBufferedIteratorProtocol<UInt8>
        private var isComplete: Bool = false
        private var bufferSize: Int = 0

        init(storage: Storage) {
            self.iterator = storage.sequence.makeAsyncIterator()
            self.bufferSize = storage.bufferSize
        }

        public mutating func next() async throws -> Data? {
            guard !isComplete else { return nil }
            guard let result = try await getNextBuffer(&iterator) else {
                isComplete = true
                return nil
            }
            return result
        }

        private func getNextBuffer(_ iterator: inout some AsyncBufferedIteratorProtocol<UInt8>) async throws -> Data? {
            guard let buffer = try await iterator.nextBuffer(suggested: bufferSize) else {
                return nil
            }
            return Data(buffer)
        }
    }
}
