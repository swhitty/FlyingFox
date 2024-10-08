//
//  WSFrameValidatorTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 19/03/2022.
//  Copyright © 2022 Simon Whitty. All rights reserved.
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
import Foundation
import Testing

struct WSFrameValidatorTests {

    @Test
    func continuationFrames_AreAppended() async throws {
        let frames = WSFrame.makeTextFrames("Fish & Chips🍟", maxCharacters: 2)
        #expect(frames.count == 7)

        #expect(
            try await WSFrameValidator.validate(frames).collectAll() == [
                WSFrame(fin: true, opcode: .text, mask: nil, payload: "Fish & Chips🍟".data(using: .utf8)!)
            ]
        )
    }

    @Test
    func controlFrames_BetweenContinuations_AreHandled() async throws {
        #expect(
            try await WSFrameValidator.validate([
                .make(fin: false, isContinuation: false, text: "Hello"),
                .ping,
                .make(fin: true, isContinuation: true, text: " World!")
            ]).collectAll() == [
                .ping,
                .make(fin: true, isContinuation: false, text: "Hello World!")
            ]
        )
    }

    @Test
    func singleFrames() async throws {
        #expect(
            try await WSFrameValidator.validate([.fish, .chips, .ping, .fish, .close])
                .collectAll() == [.fish, .chips, .ping, .fish, .close]
        )
    }

    @Test
    func validation() async {
        await #expect(throws: WSFrameValidator.Error.self) {
            try await WSFrameValidator.validate([.make(fin: false), .make(fin: false)]).collectAll()
        }

        await #expect(throws: WSFrameValidator.Error.self) {
            try await WSFrameValidator.validate([.make(fin: true, opcode: .continuation)]).collectAll()
        }
    }

    @Test
    func controlFrames_ThrowError_WhenNotFin() async {
        await #expect(throws: WSFrameValidator.Error.self) {
            try await WSFrameValidator.validate([.make(fin: false, opcode: .ping)]).collectAll()
        }
        await #expect(throws: WSFrameValidator.Error.self) {
            try await WSFrameValidator.validate([.make(fin: false, opcode: .pong)]).collectAll()
        }
        await #expect(throws: WSFrameValidator.Error.self) {
            try await WSFrameValidator.validate([.make(fin: false, opcode: .close)]).collectAll()
        }
    }
}

private extension WSFrameValidator {

    static func validate(_ frames: [WSFrame]) async throws -> AsyncThrowingStream<WSFrame, any Swift.Error> {
        UnsafeFrames(frames: frames).makeStream()
    }
}

private final class UnsafeFrames: @unchecked Sendable {

    var iterator: AsyncThrowingCompactMapSequence<AsyncThrowingStream<WSFrame, any Error>, WSFrame>.Iterator

    init(frames: [WSFrame]) {
        self.iterator = WSFrameValidator.validateFrames(from: AsyncThrowingStream.make(frames)).makeAsyncIterator()
    }

    func makeStream() -> AsyncThrowingStream<WSFrame, any Error> {
        AsyncThrowingStream { try await self.nextFrame() }
    }

    func nextFrame() async throws -> WSFrame? {
        try await iterator.next()
    }
}

