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

    package init(contentsOf fileURL: URL) {
        self.fileURL = fileURL
    }

    package func makeAsyncIterator() -> Iterator {
        Iterator(fileURL: fileURL)
    }

    package struct Iterator: AsyncBufferedIteratorProtocol {

        private let fileURL: URL
        private var fileHandle: FileHandle?

        init(fileURL: URL) {
            self.fileURL = fileURL
        }

        private mutating func makeOrGetFileHandle() throws -> FileHandle {
            guard let fileHandle else {
                let handle = try FileHandle(forReadingFrom: fileURL)
                self.fileHandle = handle
                return handle
            }
            return fileHandle
        }

        package mutating func next() async throws -> UInt8? {
            try makeOrGetFileHandle().read(suggestedCount: 1)?.first
        }

        package mutating func nextBuffer(suggested count: Int) async throws -> Data? {
            try makeOrGetFileHandle().read(suggestedCount: count)
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

package extension AsyncBufferedFileSequence {

    static func fileSize(at url: URL) throws -> Int {
        try fileSize(from: FileManager.default.attributesOfItem(atPath: url.path))
    }

    internal static func fileSize(from att: [FileAttributeKey: Any]) throws -> Int {
        guard let size = att[.size] as? UInt64 else {
            throw FileSizeError()
        }
        return Int(size)
    }

    internal struct FileSizeError: LocalizedError {
        package var errorDescription: String? = "File size not found"
    }
}
