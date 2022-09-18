//
//  WSHandlerTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 20/03/2022.
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
import XCTest

final class WSHandlerTests: XCTestCase {

    func testFrames_CreateExpectedMessages() {
        let handler = MessageFrameWSHandler.make()

        XCTAssertEqual(
            try handler.makeMessage(for: .make(fin: true, opcode: .text, payload: "Hello".data(using: .utf8)!)),
            .text("Hello")
        )
        XCTAssertThrowsError(
            try handler.makeMessage(for: .make(fin: true, opcode: .text, payload: Data([0x03, 0xE8])))
        )

        XCTAssertEqual(
            try handler.makeMessage(for: .make(fin: true, opcode: .binary, payload: Data([0x01, 0x02]))),
            .data(Data([0x01, 0x02]))
        )

        XCTAssertNil(
            try handler.makeMessage(for: .make(fin: true, opcode: .ping))
        )
        XCTAssertNil(
            try handler.makeMessage(for: .make(fin: true, opcode: .pong))
        )
        XCTAssertNil(
            try handler.makeMessage(for: .make(fin: true, opcode: .close))
        )
    }

    func testMessages_CreateExpectedFrames() {
        let handler = MessageFrameWSHandler.make()
        XCTAssertEqual(
            handler.makeFrames(for: .text("Jack of Hearts")),
            [.make(fin: true, opcode: .text, payload: "Jack of Hearts".data(using: .utf8)!)]
        )
        XCTAssertEqual(
            handler.makeFrames(for: .data(Data([0x01, 0x02]))),
            [.make(fin: true, opcode: .binary, payload: Data([0x01, 0x02]))]
        )
    }

    func testMessages_AreSplitIntoMultipleFrames() {
        let handler = MessageFrameWSHandler.make(frameSize: 4)

        XCTAssertEqual(
            handler.makeFrames(for: .text("Jack of Hearts")),
            [.make(fin: false, opcode: .text, payload: "Jack".data(using: .utf8)!),
             .make(fin: false, opcode: .continuation, payload: " of ".data(using: .utf8)!),
             .make(fin: false, opcode: .continuation, payload: "Hear".data(using: .utf8)!),
             .make(fin: true, opcode: .continuation, payload: "ts".data(using: .utf8)!)]
        )
    }

    func testMessages_ThrowError_WhenAttemptedToBeConvertedToResponseFrames() {
        let handler = MessageFrameWSHandler.make()
        XCTAssertThrowsError(
            try handler.makeResponseFrames(for: .make(fin: true, opcode: .text, payload: "Lily".data(using: .utf8)!)),
            of: MessageFrameWSHandler.FrameError.self
        )
    }

    func testResponseFrames() async throws {
        let messages = Messages()
        let handler = MessageFrameWSHandler.make(handler: messages)

        let frames = try await handler.makeFrames(for: [.fish, .ping, .pong, .chips, .close])

        await AsyncAssertEqual(
            try await messages.input.takeNext(),
            .text("Fish")
        )

        await AsyncAssertEqual(
            try await messages.input.takeNext(),
            .text("Chips")
        )

        await AsyncAssertEqual(
            try await frames.collectAll(),
            [.pong, .close(message: "Goodbye")]
        )
    }

    func testResponseFramesEnds() async throws {
        let handler = MessageFrameWSHandler.make()
        let frames = try await handler.makeFrames(for: [.ping])

        await AsyncAssertEqual(
            try await frames.collectAll(),
            [.pong]
        )
    }
}

private extension MessageFrameWSHandler {

    static func make(handler: WSMessageHandler = Messages(),
                     frameSize: Int = 1024) -> Self {
        MessageFrameWSHandler(handler: handler,
                              frameSize: frameSize)
    }

    func makeFrames(for frames: [WSFrame]) async throws -> AsyncStream<WSFrame> {
        try await makeFrames(for: .make(frames))
    }
}

private final class Messages: WSMessageHandler, @unchecked Sendable {

    var input: AsyncStream<WSMessage>!
    var output: AsyncStream<WSMessage>.Continuation!

    func makeMessages(for request: AsyncStream<WSMessage>) async throws -> AsyncStream<WSMessage> {
        self.input = request
        return AsyncStream<WSMessage> {
            self.output = $0
        }
    }
}
