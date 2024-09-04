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
import Foundation
import Testing

struct HTTPBodySequenceTests {

    @Test
    func emptyPayload_ReturnsEmptyData() async throws {
        let sequence = HTTPBodySequence()

        #expect(
            try await sequence.get() == Data()
        )
    }

    @Test
    func emptyPayload_ReturnNilBuffer() async throws {
        let sequence = HTTPBodySequence()

        var iterator = sequence.makeAsyncIterator()

        #expect(
            try await iterator.next() == nil
        )
    }

    @Test
    func dataPayload_IsReturnedInOneIteration() async throws {
        let sequence = HTTPBodySequence(bytes: [
            0x00, 0x01, 0x02, 0x03, 0x04
        ])

        var iterator = sequence.makeAsyncIterator()

        #expect(
            try await iterator.next() == Data([0x00, 0x01, 0x02, 0x03, 0x04])
        )

        #expect(
            try await iterator.next() == nil
        )
    }

    @Test
    func dataPayload_CanBeIteratedMultipleTimes() async throws {
        let data = Data([
            0x00, 0x01, 0x02
        ])

        let sequence = HTTPBodySequence(data: data)

        #expect(
            try await sequence.get() == data
        )

        #expect(
            try await sequence.get() == data
        )

        #expect(
            try await sequence.get() == data
        )
    }

    @Test
    func dataPayload_ReturnsCount() {
        #expect(
            HTTPBodySequence().count == 0
        )
        #expect(
            HTTPBodySequence(bytes: [0x0]).count == 1
        )
        #expect(
            HTTPBodySequence(bytes: [0x00, 0x01, 0x02, 0x03, 0x04]).count == 5
        )
    }

    @Test
    func sequencePayload_ReturnsCount() {
        #expect(
            HTTPBodySequence.make(from: []).count == 0
        )
        #expect(
            HTTPBodySequence.make(from: [0x0]).count == 1
        )
        #expect(
            HTTPBodySequence.make(from: [0x00, 0x01, 0x02, 0x03, 0x04]).count == 5
        )
    }

    @Test
    func sequencePayload_CanBeReturned() async throws {
        let sequence = HTTPBodySequence.make(
            from: [0x00, 0x01, 0x02, 0x03, 0x04],
            chunkSize: 2
        )

        #expect(
            try await sequence.get() == Data([0x00, 0x01, 0x02, 0x03, 0x04])
        )
    }

    @Test
    func sequencePayload_CanBeIterated() async throws {
        let sequence = HTTPBodySequence.make(
            from: [0x00, 0x01, 0x02, 0x03, 0x04],
            chunkSize: 2
        )

        var iterator = sequence.makeAsyncIterator()

        #expect(
            try await iterator.next() == Data([0x00, 0x01])
        )

        #expect(
            try await iterator.next() == Data([0x02, 0x03])
        )

        #expect(
            try await iterator.next() == Data([0x04])
        )

        #expect(
            try await iterator.next() == nil
        )
    }

    @Test
    func sequencePayloadA_IsFlushed() async throws {
        // given
        let body = HTTPBodySequence.make(
            from: [0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9],
            bufferSize: 3
        )

        // when then
        #expect(
            try await body.collectAll() == [
                Data([0x0, 0x1, 0x2]),
                Data([0x3, 0x4, 0x5]),
                Data([0x6, 0x7, 0x8]),
                Data([0x9])
            ]
        )
    }

    @Test
    func sequencePayload_IsFlushed() async {
        // given
        let buffer = ConsumingAsyncSequence(
            bytes: [0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9]
        )

        let sequence = HTTPBodySequence(shared: buffer, count: 10)

        // then
        #expect(buffer.index == 0)

        // when
        await #expect(throws: Never.self) {
            try await sequence.flushIfNeeded()
        }

        // then
        #expect(buffer.index == 10)
    }

    @Test
    func filePayloadCanReplay() async throws {
        let sequence = try HTTPBodySequence(file: .fishJSON, suggestedBufferSize: 1)

        #expect(sequence.canReplay)
        #expect(
            try await sequence.get() == Data(contentsOf: .fishJSON)
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
