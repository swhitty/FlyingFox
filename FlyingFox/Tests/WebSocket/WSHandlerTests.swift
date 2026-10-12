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
@testable import FlyingSocks
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
        let collected = Task { try await frames.collectAll() }

        #expect(
            try await messages.input.takeNext() == .text("Fish")
        )

        #expect(
            try await messages.input.takeNext() == .text("Chips")
        )

        #expect(
            try await collected.value == [.pong, .close]
        )
    }

    @Test
    func closeFrame_IsEchoed_AndDeliveredAsFinalMessage() async throws {
        let messages = Messages()
        let handler = MessageFrameWSHandler.make(handler: messages)

        let frames = try await handler.makeFrames(for: [.close])

        #expect(
            try await frames.collectAll() == [.close]
        )
        #expect(
            try await messages.input.collectAll() == [.close(WSCloseCode(1002, reason: "Bye"))]
        )
    }

    @Test
    func clientFrames_AreRead_OnlyAsMessagesAreTaken() async throws {
        let read = Mutex(0)
        let messages = Messages()
        let handler = MessageFrameWSHandler.make(handler: messages)

        let frames = try await handler.makeFrames(for: AsyncThrowingStream {
            read.withLock { $0 += 1 }
            return .fish
        })

        #expect(
            try await messages.input.takeNext() == .text("Fish")
        )
        // The frame taken has been read, and at most one more waits to be taken.
        #expect(read.withLock { $0 } <= 2)
        withExtendedLifetime(frames) { }
    }

    @Test
    func messagesOut_ArePulled_OnlyAsFramesAreTaken() async throws {
        let pulled = Mutex(0)
        let handler = MessageFrameWSHandler.make(handler: UnfoldingMessages {
            pulled.withLock { $0 += 1 }
            return .text("Hello")
        })
        let (clientFrames, clientContinuation) = AsyncThrowingStream<WSFrame, any Error>.makeStream()
        defer { clientContinuation.finish() }

        let frames = try await handler.makeFrames(for: clientFrames)

        var iterator = frames.makeAsyncIterator()
        #expect(
            try await iterator.next() == .make(fin: true, opcode: .text, payload: "Hello".data(using: .utf8)!)
        )
        // The message taken has been pulled, and at most one more waits to be taken.
        #expect(pulled.withLock { $0 } <= 2)
    }

    @Test
    func responseFramesEnds() async throws {
        let handler = MessageFrameWSHandler.make()
        let frames = try await handler.makeFrames(for: [.ping])

        #expect(
            try await frames.collectAll() == [.pong]
        )
    }

    @Test
    func messagesOut_Ends_WhenCloseMessageIsSent() async throws {
        let messages = Messages()
        let handler = MessageFrameWSHandler.make(handler: messages)
        let frames = try await handler.makeFrames(for: [])

        messages.output.yield(.close(.normalClosure))

        #expect(
            try await frames.collectAll() == [.close(code: .normalClosure)]
        )
    }

    @Test
    func messagesOut_YieldsFrames() async throws {
        let messages = Messages()
        let handler = MessageFrameWSHandler.make(handler: messages)
        let (clientFrames, clientContinuation) = AsyncThrowingStream<WSFrame, any Error>.makeStream()

        defer {
            clientContinuation.finish()
            messages.output.finish()
        }

        let frames = try await handler.makeFrames(for: clientFrames)

        messages.output.yield(.text("Hello"))

        var iterator = frames.makeAsyncIterator()
        #expect(
            try await iterator.next() == .make(fin: true, opcode: .text, payload: "Hello".data(using: .utf8)!)
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

// Produces each outgoing message when asked for it, as a handler that must
// wait for a message to be taken before producing the next one would.
private struct UnfoldingMessages: WSMessageHandler {

    let next: @Sendable () async -> WSMessage?

    func makeMessages(for client: AsyncStream<WSMessage>) async throws -> AsyncStream<WSMessage> {
        AsyncStream(unfolding: next)
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
