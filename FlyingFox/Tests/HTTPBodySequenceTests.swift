//
//  HTTPBodySequenceTests.swift
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

@testable import FlyingFox
import FlyingSocks
import XCTest

final class HTTPBodySequenceTests: XCTestCase {

    func testEmptyPayload_ReturnsEmptyData() async {
        let sequence = HTTPBodySequence()

        await AsyncAssertEqual(
            try await sequence.get(),
            Data()
        )
    }

    func testEmptyPayload_ReturnNilBuffer() async {
        let sequence = HTTPBodySequence()

        var iterator = sequence.makeAsyncIterator()

        await AsyncAssertNil(
            try await iterator.next()
        )
    }

    func testDataPayload_IsReturnedInOneIteration() async {
        let sequence = HTTPBodySequence(bytes: [
            0x00, 0x01, 0x02, 0x03, 0x04
        ])

        var iterator = sequence.makeAsyncIterator()

        await AsyncAssertEqual(
            try await iterator.next(),
            Data([0x00, 0x01, 0x02, 0x03, 0x04])
        )

        await AsyncAssertNil(
            try await iterator.next()
        )
    }

    func testDataPayload_CanBeIteratedMultipleTimes() async {
        let data = Data([
            0x00, 0x01, 0x02
        ])

        let sequence = HTTPBodySequence(data: data)

        await AsyncAssertEqual(
            try await sequence.get(),
            data
        )

        await AsyncAssertEqual(
            try await sequence.get(),
            data
        )

        await AsyncAssertEqual(
            try await sequence.get(),
            data
        )
    }

    func testDataPayload_ReturnsCount() {
        XCTAssertEqual(
            HTTPBodySequence().count,
            0
        )
        XCTAssertEqual(
            HTTPBodySequence(bytes: [0x0]).count,
            1
        )
        XCTAssertEqual(
            HTTPBodySequence(bytes: [0x00, 0x01, 0x02, 0x03, 0x04]).count,
            5
        )
    }

    func testSequencePayload_ReturnsCount() {
        XCTAssertEqual(
            HTTPBodySequence.make(from: []).count,
            0
        )
        XCTAssertEqual(
            HTTPBodySequence.make(from: [0x0]).count,
            1
        )
        XCTAssertEqual(
            HTTPBodySequence.make(from: [0x00, 0x01, 0x02, 0x03, 0x04]).count,
            5
        )
    }

    func testSequencePayload_CanBeReturned() async {
        let sequence = HTTPBodySequence.make(
            from: [0x00, 0x01, 0x02, 0x03, 0x04],
            chunkSize: 2
        )

        await AsyncAssertEqual(
            try await sequence.get(),
            Data([0x00, 0x01, 0x02, 0x03, 0x04])
        )
    }

    func testSequencePayload_CanBeIterated() async {
        let sequence = HTTPBodySequence.make(
            from: [0x00, 0x01, 0x02, 0x03, 0x04],
            chunkSize: 2
        )

        var iterator = sequence.makeAsyncIterator()

        await AsyncAssertEqual(
            try await iterator.next(),
            Data([0x00, 0x01])
        )

        await AsyncAssertEqual(
            try await iterator.next(),
            Data([0x02, 0x03])
        )

        await AsyncAssertEqual(
            try await iterator.next(),
            Data([0x04])
        )

        await AsyncAssertNil(
            try await iterator.next()
        )
    }

    func testSequencePayloadA_IsFlushed() async throws {
        // given
        let body = HTTPBodySequence.make(
            from: [0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9],
            bufferSize: 3
        )

        // when then
        await AsyncAssertEqual(
            try await body.collectAll(),
            [
                Data([0x0, 0x1, 0x2]),
                Data([0x3, 0x4, 0x5]),
                Data([0x6, 0x7, 0x8]),
                Data([0x9])
            ]
        )
    }

    func testSequencePayload_IsFlushed() async {
        // given
        let buffer = ConsumingAsyncSequence(
            bytes: [0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9]
        )

        let sequence = HTTPBodySequence(shared: buffer, count: 10)

        // then
        XCTAssertEqual(buffer.index, 0)

        // when
        await AsyncAssertNoThrow(
            try await sequence.flushIfNeeded()
        )

        // then
        XCTAssertEqual(buffer.index, 10)
    }

    func testFilePayloadCanReplay() async throws {
        let sequence = try HTTPBodySequence(file: .fishJSON, suggestedBufferSize: 1)

        XCTAssertTrue(sequence.canReplay)
        await AsyncAssertEqual(
            try await sequence.get(),
            try Data(contentsOf: .fishJSON)
        )
    }
}

private extension URL {
    static var fishJSON: URL {
        Bundle.module.url(forResource: "Stubs/fish.json", withExtension: nil)!
    }
}

private extension HTTPBodySequence {

    init(bytes: [UInt8]) {
        self.init(data: Data(bytes))
    }

    static func make(from bytes: [UInt8], count: Int? = nil, chunkSize: Int = 2) -> Self {
        HTTPBodySequence(
            from: ConsumingAsyncSequence(bytes),
            count: count ?? bytes.count,
            suggestedBufferSize: chunkSize
        )
    }

    static func make(from bytes: [UInt8], bufferSize: Int) -> Self {
        HTTPBodySequence(
            data: Data(bytes),
            suggestedBufferSize: bufferSize
        )
    }
}
