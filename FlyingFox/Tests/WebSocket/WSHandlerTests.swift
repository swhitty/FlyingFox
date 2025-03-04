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
import Testing

struct WSHandlerTests {

    @Test
    func frames_CreateExpectedMessages() throws {
        let handler = MessageFrameWSHandler.make()

        #expect(
            try handler.makeMessage(for: .make(fin: true, opcode: .text, payload: "Hello".data(using: .utf8)!)) == .text("Hello")
        )
        #expect(throws: (any Error).self) {
            try handler.makeMessage(for: .make(fin: true, opcode: .text, payload: Data([0x03, 0xE8])))
        }
        #expect(
            try handler.makeMessage(for: .make(fin: true, opcode: .binary, payload: Data([0x01, 0x02]))) == .data(Data([0x01, 0x02]))
        )
        #expect(
            try handler.makeMessage(for: .make(fin: true, opcode: .ping)) == nil
        )
        #expect(
            try handler.makeMessage(for: .make(fin: true, opcode: .pong)) == nil
        )
    }

    @Test
    func frames_CreatesCloseMessage() throws {
        let handler = MessageFrameWSHandler.make()
        let payload = Data([0x13, 0x87, .ascii("f"), .ascii("i"), .ascii("s"), .ascii("h")])

        #expect(
            try handler.makeMessage(for: .make(fin: true, opcode: .close, payload: payload)) ==
                .close(WSCloseCode(4999, reason: "fish"))
        )
        #expect(
            try handler.makeMessage(for: .make(fin: true, opcode: .close)) ==
                .close(.noStatusReceived)
        )
    }

    @Test
    func messages_CreateExpectedFrames() {
        let handler = MessageFrameWSHandler.make()
        #expect(
            handler.makeFrames(for: .text("Jack of Hearts")) == [
                .make(fin: true, opcode: .text, payload: "Jack of Hearts".data(using: .utf8)!)
            ]
        )
        #expect(
            handler.makeFrames(for: .data(Data([0x01, 0x02]))) == [
                .make(fin: true, opcode: .binary, payload: Data([0x01, 0x02]))
            ]
        )
    }

    @Test
    func messages_AreSplitIntoMultipleFrames() {
        let handler = MessageFrameWSHandler.make(frameSize: 4)

        #expect(
            handler.makeFrames(for: .text("Jack of Hearts")) == [
                .make(fin: false, opcode: .text, payload: "Jack".data(using: .utf8)!),
                .make(fin: false, opcode: .continuation, payload: " of ".data(using: .utf8)!),
                .make(fin: false, opcode: .continuation, payload: "Hear".data(using: .utf8)!),
                .make(fin: true, opcode: .continuation, payload: "ts".data(using: .utf8)!)
            ]
        )
    }

    @Test
    func messages_ThrowError_WhenAttemptedToBeConvertedToResponseFrames() {
        let handler = MessageFrameWSHandler.make()
        #expect(throws: MessageFrameWSHandler.FrameError.self) {
            try handler.makeResponseFrames(for: .make(fin: true, opcode: .text, payload: "Lily".data(using: .utf8)!))
        }
    }

    @Test
    func responseFrames() async throws {
        let messages = Messages()
        let handler = MessageFrameWSHandler.make(handler: messages)

        let frames = try await handler.makeFrames(for: [.fish, .ping, .pong, .chips, .close])

        #expect(
            try await messages.input.takeNext() == .text("Fish")
        )

        #expect(
            try await messages.input.takeNext() == .text("Chips")
        )

        #expect(
            try await frames.collectAll() == [.pong, .close]
        )
    }

    @Test
    func responseFramesEnds() async throws {
        let handler = MessageFrameWSHandler.make()
        let frames = try await handler.makeFrames(for: [.ping])

        #expect(
            try await frames.collectAll() == [.pong]
        )
    }
}

extension MessageFrameWSHandler {

    static func make(handler: some WSMessageHandler = Messages(),
                     frameSize: Int = 1024) -> Self {
        MessageFrameWSHandler(handler: handler,
                              frameSize: frameSize)
    }

    func makeFrames(for frames: [WSFrame]) async throws -> AsyncStream<WSFrame> {
        try await makeFrames(for: .make(frames))
    }
}

final class Messages: WSMessageHandler, @unchecked Sendable {

    var input: AsyncStream<WSMessage>!
    var output: AsyncStream<WSMessage>.Continuation!

    func makeMessages(for request: AsyncStream<WSMessage>) async throws -> AsyncStream<WSMessage> {
        self.input = request
        return AsyncStream<WSMessage> {
            self.output = $0
        }
    }
}
