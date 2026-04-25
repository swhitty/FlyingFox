//
//  HTTPChunkedDecodedSequence.swift
//  FlyingFox
//
//  Created by Simon Whitty on 24/04/2026.
//  Copyright © 2026 Simon Whitty. All rights reserved.
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

// Decodes an `AsyncBufferedSequence` of bytes that are framed using the
// `chunked` transfer coding (RFC 9112 §7.1) and yields the decoded payload.
struct HTTPChunkedTransferDecoder<Base>: AsyncBufferedSequence, Sendable
    where Base: AsyncBufferedSequence,
          Base.Element == UInt8,
          Base: Sendable {
    typealias Element = UInt8

    private let bytes: Base

    init(bytes: Base) {
        self.bytes = bytes
    }

    func makeAsyncIterator() -> Iterator {
        Iterator(bytes: bytes.makeAsyncIterator())
    }
}

extension HTTPChunkedTransferDecoder {

    struct Iterator: AsyncBufferedIteratorProtocol {

        private var bytes: Base.AsyncIterator
        private var remainingInChunk: Int = 0
        private var isComplete: Bool = false

        init(bytes: Base.AsyncIterator) {
            self.bytes = bytes
        }

        mutating func next() async throws -> UInt8? {
            fatalError("call nextBuffer(suggested:)")
        }

        mutating func nextBuffer(suggested count: Int) async throws -> [UInt8]? {
            guard !isComplete else { return nil }

            if remainingInChunk == 0 {
                let size = try await readChunkSize()
                if size == 0 {
                    try await consumeTrailer()
                    isComplete = true
                    return nil
                }
                remainingInChunk = size
            }

            let take = Swift.min(count, remainingInChunk)
            guard let buffer = try await bytes.nextBuffer(count: take) else {
                throw HTTPDecoder.Error("Unexpected end of chunked body")
            }
            remainingInChunk -= buffer.count
            if remainingInChunk == 0 {
                try await consumeCRLF()
            }
            return buffer
        }

        // RFC 9112 §7.1: chunk = chunk-size [ chunk-ext ] CRLF chunk-data CRLF
        // chunk-size is hexadecimal; chunk-ext (preceded by `;`) is ignored here.
        private mutating func readChunkSize() async throws -> Int {
            let line = try await readLine()
            let sizePart = line.split(separator: ";", maxSplits: 1).first.map(String.init) ?? line
            guard let size = Int(sizePart, radix: 16), size >= 0 else {
                throw HTTPDecoder.Error("Invalid chunk-size: \(line)")
            }
            return size
        }

        // RFC 9112 §7.1.2: trailer-section is zero or more field lines terminated by CRLF.
        private mutating func consumeTrailer() async throws {
            while !(try await readLine()).isEmpty { }
        }

        private mutating func consumeCRLF() async throws {
            guard let buffer = try await bytes.nextBuffer(count: 2),
                  buffer == [0x0D, 0x0A] else {
                throw HTTPDecoder.Error("Expected CRLF after chunk-data")
            }
        }

        private mutating func readLine() async throws -> String {
            var line = [UInt8]()
            while true {
                guard let buffer = try await bytes.nextBuffer(count: 1) else {
                    throw HTTPDecoder.Error("Unexpected end of chunked body")
                }
                let byte = buffer[0]
                if byte == 0x0A {
                    if line.last == 0x0D { line.removeLast() }
                    return String(decoding: line, as: UTF8.self)
                }
                line.append(byte)
            }
        }
    }
}
