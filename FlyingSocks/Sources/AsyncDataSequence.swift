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

    public init(from bytes: some AsyncBufferedSequence<UInt8>, count: Int, chunkSize: Int) {
        self.loader = DataLoader(
            count: count,
            chunkSize: chunkSize,
            iterator: AsyncBufferedSequenceIterator(bytes.makeAsyncIterator())
        )
    }

    public init(file handle: FileHandle, count: Int, chunkSize: Int) {
        self.loader = DataLoader(
            count: count,
            chunkSize: chunkSize,
            iterator: AsyncFileHandleIterator(handle: handle)
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

    public func flushIfNeeded() async throws {
        try await loader.flushIfNeeded()
    }
}

public extension AsyncDataSequence {

    static func size(of file: URL) throws -> Int {
        let att = try FileManager.default.attributesOfItem(atPath: file.path)
        guard let size = att[.size] as? UInt64 else {
            throw FileSizeError()
        }
        return Int(size)
    }

    struct FileSizeError: LocalizedError {
        public var errorDescription: String? = "File size not found"
    }
}

private extension AsyncDataSequence {

    actor DataLoader {
        nonisolated fileprivate let count: Int
        nonisolated fileprivate let chunkSize: Int
        private let iterator: any AsyncDataIterator & Sendable
        private var state: State

        init(count: Int, chunkSize: Int, iterator: some AsyncDataIterator & Sendable) {
            self.count = count
            self.chunkSize = chunkSize
            self.iterator = iterator
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
                state = .ready(index: index + element.count)
                return Data(element)
            } catch {
                state = .complete
                throw error
            }
        }

        public func flushIfNeeded() async throws {
            switch state {
            case .ready(index: var index):
                while let data = try await nextData(from: index) {
                    index += data.count
                }
                return
            case .fetching:
                throw Error.unexpectedState
            case .complete:
                return
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

    final class AsyncBufferedSequenceIterator<I: AsyncBufferedIteratorProtocol>: AsyncDataIterator, @unchecked Sendable where I.Element == UInt8 {
        private var iterator: I

        init(_ iterator: I) {
            self.iterator = iterator
        }

        func nextChunk(count: Int) async throws -> Data? {
            guard let buffer = try await iterator.nextBuffer(count: count) else { return nil }
            return Data(buffer)
        }
    }

    struct AsyncFileHandleIterator: AsyncDataIterator {
        let handle: FileHandle?

        func nextChunk(count: Int) throws -> Data? {
            guard let handle = handle else { throw SocketError.disconnected }
            return handle.readData(ofLength: count)
        }
    }
}

private protocol AsyncDataIterator {
    func nextChunk(count: Int) async throws -> Data?
}

