//
//  AsyncDataSequenceTests.swift
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

import FlyingSocks
@_spi(Private) import struct FlyingSocks.AsyncDataSequence
import XCTest

final class AsyncDataSequenceTests: XCTestCase {

    func testDataCount() async throws {
        XCTAssertEqual(
            AsyncDataSequence.make(from: []).count,
            0
        )
        XCTAssertEqual(
            AsyncDataSequence.make(from: [0x0]).count,
            1
        )
        XCTAssertEqual(
            AsyncDataSequence.make(from: [0x0, 0x1]).count,
            2
        )
        XCTAssertEqual(
            AsyncDataSequence.make(
                from: [0x0, 0x1, 0x2, 0x3, 0x4, 0x5]
            ).count,
            6
        )
    }

    func testData_IsReturnedInChunks() async {
        let sequence = AsyncDataSequence.make(
            from: [0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9],
            chunkSize: 3
        )

        var iterator = sequence.makeAsyncIterator()

        await AsyncAssertEqual(
            try await iterator.next(),
            Data([0x0, 0x1, 0x2])
        )

        await AsyncAssertEqual(
            try await iterator.next(),
            Data([0x3, 0x4, 0x5])
        )

        await AsyncAssertEqual(
            try await iterator.next(),
            Data([0x6, 0x7, 0x8])
        )

        await AsyncAssertEqual(
            try await iterator.next(),
            Data([0x9])
        )

        await AsyncAssertNil(
            try await iterator.next()
        )
    }

    func testPrematureEnd_ThrowsError() async {
        let sequence = AsyncDataSequence.make(
            from: [0x0, 0x1, 0x2, 0x3],
            count: 100,
            chunkSize: 3
        )

        var iterator = sequence.makeAsyncIterator()

        await AsyncAssertEqual(
            try await iterator.next(),
            Data([0x0, 0x1, 0x2])
        )

        await AsyncAssertThrowsError(
            try await iterator.next()
        )
    }

    func testMultipleIterations_ThrowsError() async {
        let sequence = AsyncDataSequence.make(
            from: [0x0, 0x1],
            chunkSize: 1
        )

        var it1 = sequence.makeAsyncIterator()
        var it2 = sequence.makeAsyncIterator()

        await AsyncAssertEqual(
            try await it1.next(),
            Data([0x0])
        )

        await AsyncAssertThrowsError(
            try await it2.next()
        )

        await AsyncAssertEqual(
            try await it1.next(),
            Data([0x1])
        )

        await AsyncAssertNil(
            try await it1.next()
        )
    }

    func testIsFlushed_FromStart() async {
        // given
        let buffer = ConsumingAsyncSequence<UInt8>(
            [0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9]
        )
        let sequence = AsyncDataSequence(from: buffer, count: 10, chunkSize: 2)

        // then
        XCTAssertEqual(buffer.index, 0)

        // when
        await AsyncAssertNoThrow(
            try await sequence.flushIfNeeded()
        )

        // then
        XCTAssertEqual(buffer.index, 10)
    }

    func testIsFlushed_FromEnd() async {
        // given
        let buffer = ConsumingAsyncSequence<UInt8>(
            [0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9]
        )
        let sequence = AsyncDataSequence(from: buffer, count: 10, chunkSize: 2)
        await AsyncAssertNoThrow(
            try await sequence.get()
        )

        // then
        XCTAssertEqual(buffer.index, 10)

        // when
        await AsyncAssertNoThrow(
            try await sequence.flushIfNeeded()
        )

        // then
        XCTAssertEqual(buffer.index, 10)
    }

    func testIsFlushed_FromMiddle() async {
        // given
        let buffer = ConsumingAsyncSequence<UInt8>(
            [0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9]
        )
        let sequence = AsyncDataSequence(from: buffer, count: 10, chunkSize: 2)
        await AsyncAssertNoThrow(
            try await sequence.first()
        )

        // then
        XCTAssertEqual(buffer.index, 2)

        // when
        await AsyncAssertNoThrow(
            try await sequence.flushIfNeeded()
        )

        // then
        XCTAssertEqual(buffer.index, 10)
    }

    func testFileCount() throws {
        let sequence = try AsyncDataSequence.make(file: .jackOfHeartsRecital, chunkSize: 100)
        XCTAssertEqual(sequence.count, 299)
    }

    func testFile_IsReturnedInChunks() async throws {
        let sequence = try AsyncDataSequence.make(file: .jackOfHeartsRecital, chunkSize: 100)
        var iterator = sequence.makeAsyncIterator()

        await AsyncAssertEqual(
            try await iterator.next()?.count,
            100
        )

        await AsyncAssertEqual(
            try await iterator.next()?.count,
            100
        )

        await AsyncAssertEqual(
            try await iterator.next()?.count,
            99
        )

        await AsyncAssertNil(
            try await iterator.next()
        )
    }
}

private extension URL {
    static var jackOfHeartsRecital: URL {
        Bundle.module.url(forResource: "Resources", withExtension: nil)!
            .appendingPathComponent("JackOfHeartsRecital.txt")
    }
}

extension AsyncDataSequence {

    static func make(from bytes: [UInt8], count: Int? = nil, chunkSize: Int = 2) -> Self {
        AsyncDataSequence(
            from: ConsumingAsyncSequence(bytes),
            count: count ?? bytes.count,
            chunkSize: chunkSize
        )
    }

    static func make(file url: URL, chunkSize: Int = 2) throws -> Self {
        try AsyncDataSequence(
            file: FileHandle(forReadingFrom: url),
            count: AsyncDataSequence.size(of: url),
            chunkSize: chunkSize
        )
    }

    func get() async throws -> Data {
        try await reduce(into: Data()) {
            $0.append($1)
        }
    }

    func first() async throws -> Data {
        guard let element = try await first(where: { _ in true }) else {
            throw SocketError.disconnected
        }
        return element
    }
}

private final class ConsumingAsyncSequence<Element>: AsyncBufferedSequence, AsyncBufferedIteratorProtocol {

    private var iterator: AnySequence<Element>.Iterator
    private(set) var index: Int = 0

    init<T: Sequence>(_ sequence: T) where T.Element == Element {
        self.iterator = AnySequence(sequence).makeIterator()
    }

    func makeAsyncIterator() -> ConsumingAsyncSequence<Element> { self }

    func next() async throws -> Element? {
        iterator.next()
    }

    func nextBuffer(atMost count: Int) async throws -> [Element]? {
        var buffer = [Element]()
        while buffer.count < count,
              let element = iterator.next() {
            buffer.append(element)
        }

        index += buffer.count

        return buffer.count == count ? buffer : nil
    }
}
