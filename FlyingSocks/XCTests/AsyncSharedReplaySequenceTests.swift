//
//  AsyncSharedReplaySequenceTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 22/06/2024.
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

import FlyingSocks
import Foundation
import XCTest

final class AsyncSharedReplaySequenceTests: XCTestCase {

    func testSequenceCanBeIteratorMultipleTimes() async {
        let sequence = AsyncSharedReplaySequence.make(string: "The quick brown fox")
        var iterator = sequence.makeAsyncIterator()

        await AsyncAssertEqual(
            try await iterator.collectBufferStrings(ofLength: 5),
            [
                "The q",
                "uick ",
                "brown",
                " fox"
            ]
        )

        iterator = sequence.makeAsyncIterator()
        await AsyncAssertEqual(
            try await iterator.collectBufferStrings(ofLength: 10),
            [
                "The quick ",
                "brown fox"
            ]
        )
    }

    func testSequenceCanBeIteratorMultipleTimesA() async {

        let sequence = AsyncSharedReplaySequence.make(string: "The quick brown fox")
        var iterator = sequence.makeAsyncIterator()

        await AsyncAssertEqual(
            try await iterator.next(),
            Character("T").asciiValue
        )

        iterator = sequence.makeAsyncIterator()
        await AsyncAssertEqual(
            try await iterator.next(),
            Character("T").asciiValue
        )
    }

    func testCanBeCancelled() async {
        let task = Task {
            var iterator = AsyncSharedReplaySequence
                .makeEmpty()
                .makeAsyncIterator()
            return try await iterator.nextBuffer(suggested: 1)
        }

        try? await Task.sleep(seconds: 0.05)
        task.cancel()

        await AsyncAssertNil(
            try await task.value
        )
    }
}

private extension AsyncSharedReplaySequence where Base == ConsumingAsyncSequence<AsyncBufferedCollection<Data>> {

    static func make(bytes: Data, count: Int?) -> Self {
        AsyncSharedReplaySequence(
            base: ConsumingAsyncSequence(bytes),
            count: count
        )
    }

    static func make(string: String) -> Self {
        let data = string.data(using: .utf8)!
        return make(bytes: data, count: data.count)
    }
}

private extension AsyncSharedReplaySequence where Base == AsyncBufferedEmptySequence<UInt8> {

    static func makeEmpty(count: Int = 100) -> Self {
        AsyncSharedReplaySequence(
            base: AsyncBufferedEmptySequence<UInt8>(completeImmediately: false),
            count: count
        )
    }
}

private extension AsyncSharedReplaySequence.AsyncIterator {

    mutating func collectBuffers(ofLength count: Int) async throws -> [Buffer] {
        var collected = [Buffer]()
        while let buffer = try await nextBuffer(suggested: count) {
            collected.append(buffer)
        }
        return collected
    }
}

private extension AsyncSharedReplaySequence.AsyncIterator where Element == UInt8 {

    mutating func collectBufferStrings(ofLength count: Int) async throws -> [String] {
        try await collectBuffers(ofLength: count)
            .map {
                String(data: Data($0), encoding: .utf8)!
            }
    }
}
