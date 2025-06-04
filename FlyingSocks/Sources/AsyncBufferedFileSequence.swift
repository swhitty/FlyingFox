//
//  AsyncBufferedFileSequence.swift
//  FlyingFox
//
//  Created by Simon Whitty on 06/06/2024.
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

package struct AsyncBufferedFileSequence: AsyncBufferedSequence {
    package typealias Element = UInt8

    private let fileURL: URL
    private let range: Range<Int>

    package let fileSize: Int
    package var count: Int { range.count }

    package init(contentsOf fileURL: URL, range: Range<Int>? = nil) throws {
        self.fileURL = fileURL
        self.fileSize = try Self.fileSize(at: fileURL)

        if let range {
            self.range = range
            guard range.lowerBound >= 0, range.upperBound <= fileSize else {
                throw FileSizeError("Invalid range \(range) for file size \(fileSize)")
            }
        } else {
            self.range = 0..<fileSize
        }
    }

    package func makeAsyncIterator() -> Iterator {
        Iterator(fileURL: fileURL, range: range)
    }

    package struct Iterator: AsyncBufferedIteratorProtocol {

        private let fileURL: URL
        private let range: Range<Int>
        private var fileHandle: FileHandle?
        private var offset: Int = 0

        init(fileURL: URL, range: Range<Int>) {
            self.fileURL = fileURL
            self.range = range
            self.offset = range.lowerBound
        }

        private mutating func makeOrGetFileHandle() throws -> FileHandle {
            guard let fileHandle else {
                let handle = try FileHandle(forReadingFrom: fileURL)
                try handle.seek(toOffset: UInt64(offset))
                self.fileHandle = handle
                return handle
            }
            return fileHandle
        }

        package mutating func next() async throws -> UInt8? {
            try makeOrGetFileHandle().read(suggestedCount: 1)?.first
        }

        package mutating func nextBuffer(suggested count: Int) async throws -> Data? {
            let endIndex = Swift.min(offset + count, range.upperBound)
            guard endIndex <= range.upperBound else {
                return nil
            }
            guard let data = try makeOrGetFileHandle().read(suggestedCount: endIndex - offset) else {
                return nil
            }

            offset += data.count
            return data
        }
    }
}

extension AsyncBufferedFileSequence: Sendable { }

extension FileHandle {

    func read(suggestedCount count: Int, forceLegacy: Bool = false) throws -> Data? {
        if #available(macOS 10.15.4, iOS 13.4, tvOS 13.4, *), !forceLegacy {
            return try read(upToCount: count)
        } else {
            return readData(ofLength: count)
        }
    }
}

extension AsyncBufferedFileSequence {

    package static func fileSize(at url: URL) throws -> Int {
        try fileSize(from: FileManager.default.attributesOfItem(atPath: url.path))
    }

    static func fileSize(from att: [FileAttributeKey: Any]) throws -> Int {
        guard let size = att[.size] as? UInt64 else {
            throw FileSizeError("File size not found")
        }
        return Int(size)
    }

    struct FileSizeError: LocalizedError {
        package var errorDescription: String?

        init(_ message: String) {
            self.errorDescription = message
        }
    }
}
