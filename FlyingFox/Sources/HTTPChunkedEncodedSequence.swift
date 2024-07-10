//
//  HTTPChunkedTransferEncoder.swift
//  FlyingFox
//
//  Created by Simon Whitty on 09/07/2024.
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
import FlyingSocks

struct HTTPChunkedTransferEncoder<Base>: AsyncBufferedSequence, Sendable
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

extension HTTPChunkedTransferEncoder {

    struct Iterator: AsyncBufferedIteratorProtocol {

        private var bytes: Base.AsyncIterator
        private var isComplete: Bool = false

        init(bytes: Base.AsyncIterator) {
            self.bytes = bytes
        }

        mutating func next() async throws -> UInt8? {
            fatalError("call nextBuffer(atMost:)")
        }

        mutating func nextBuffer(atMost count: Int) async throws -> [UInt8]? {
            guard !isComplete else { return nil }

            if let buffer = try await bytes.nextBuffer(atMost: count) {
                var response = Array<UInt8>(String(format:"%02X", buffer.count).utf8)
                response.append(contentsOf: Array("\r\n".utf8))
                response.append(contentsOf: buffer)
                response.append(contentsOf: Array("\r\n".utf8))
                return response
            } else {
                isComplete = true
                return Array("0\r\n\r\n".utf8)
            }
        }
    }
}
