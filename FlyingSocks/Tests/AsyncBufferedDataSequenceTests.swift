//
//  AsyncBufferedDataSequenceTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 10/07/2024.
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

@_spi(Private) import struct FlyingSocks.AsyncBufferedCollection
import FlyingSocks
import Foundation
import XCTest

final class AsyncBufferedDataSequenceTests: XCTestCase {

    func testSeqeunce() async {
        let buffer = AsyncBufferedCollection(bytes: [
            0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7,
            0x8, 0x9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF
        ])

        await AsyncAssertEqual(
            await buffer.collectBuffers(ofLength: 5),
            [
                Data([0x0, 0x1, 0x2, 0x3, 0x4]),
                Data([0x5, 0x6, 0x7, 0x8, 0x9]),
                Data([0xA, 0xB, 0xC, 0xD, 0xE]),
                Data([0xF])
            ]
        )
    }

    func testSequenceCanBeIteratorMultipleTimes() async {
        let buffer = AsyncBufferedCollection(bytes: [
            0x0, 0x1, 0x2
        ])

        await AsyncAssertEqual(
            await buffer.collectBuffers(ofLength: 5),
            [Data([0x0, 0x1, 0x2])]
        )

        await AsyncAssertEqual(
            await buffer.collectBuffers(ofLength: 5),
            [Data([0x0, 0x1, 0x2])]
        )
    }
}

private extension AsyncBufferedSequence {

    func collectBuffers(ofLength count: Int) async -> [AsyncIterator.Buffer] {
        var collected = [AsyncIterator.Buffer]()
        var iterator = makeAsyncIterator()

        while let buffer = try? await iterator.nextBuffer(atMost: count) {
            collected.append(buffer)
        }
        return collected
    }
}
