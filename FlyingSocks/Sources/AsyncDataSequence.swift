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

/// AsyncSequence that can only be iterated one-time-only. Suitable for large data sizes.
package struct AsyncDataSequence: AsyncSequence, Sendable {
    package typealias Element = Data

    private let loader: DataLoader

    package init(from bytes: some AsyncBufferedSequence<UInt8>, count: Int, chunkSize: Int) {
        self.loader = DataLoader(
            count: count,
            chunkSize: chunkSize,
            iterator: bytes.makeAsyncIterator()
        )
    }

    package init(file handle: FileHandle, count: Int, chunkSize: Int) {
        self.loader = DataLoader(
            count: count,
            chunkSize: chunkSize,
            iterator: AsyncFileHandleIterator(handle: handle)
        )
    }

    package var count: Int { loader.count }

    package func makeAsyncIterator() -> Iterator {
        Iterator(loader: loader)
    }

    package struct Iterator: AsyncIteratorProtocol {
        package typealias Element = Data

        private let loader: DataLoader

        private var index: Int = 0

        fileprivate init(loader: DataLoader) {
            self.loader = loader
        }

        package mutating func next() async throws -> Data? {
            let data = try await loader.nextData(from: index)
            if let data = data {
                index += data.count
            }
            return data
        }
    }

    package func flushIfNeeded() async throws {
        try await loader.flushIfNeeded()
    }
}

package extension AsyncDataSequence {

    static func size(of file: URL) throws -> Int {
        let att = try FileManager.default.attributesOfItem(atPath: file.path)
        guard let size = att[.size] as? UInt64 else {
            throw FileSizeError()
        }
        return Int(size)
    }

    struct FileSizeError: LocalizedError {
        package var errorDescription: String? = "File size not found"
    }
}

private extension AsyncDataSequence {

    actor DataLoader {
        nonisolated fileprivate let count: Int
        nonisolated fileprivate let chunkSize: Int
        private var iterator: any AsyncBufferedIteratorProtocol<UInt8>
        private var state: State

        init(count: Int, chunkSize: Int, iterator: some AsyncBufferedIteratorProtocol<UInt8> & Sendable) {
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
                guard let element = try await getNextBuffer(&iterator, suggested: nextCount) else {
                    throw Error.unexpectedEOF
                }
                state = .ready(index: index + element.count)
                return Data(element)
            } catch {
                state = .complete
                throw error
            }
        }

        private func getNextBuffer(_ iterator: inout some AsyncBufferedIteratorProtocol<UInt8>, suggested count: Int) async throws -> Data? {
            guard let buffer = try await iterator.nextBuffer(suggested: count) else {
                return nil
            }
            return Data(buffer)
        }

        package func flushIfNeeded() async throws {
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

    struct AsyncFileHandleIterator: AsyncBufferedIteratorProtocol {
        typealias Element = UInt8

        let handle: FileHandle?

        func next() async throws -> UInt8? {
            fatalError()
        }

        func nextBuffer(suggested count: Int) throws -> Data? {
            guard let handle = handle else { throw SocketError.disconnected }
            if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, *) {
                return try handle.read(upToCount: count)
            } else {
                return handle.readData(ofLength: count)
            }
        }
    }
}

