//
//  WSHandler.swift
//  FlyingFox
//
//  Created by Simon Whitty on 18/03/2022.
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

import FlyingSocks
import Foundation

public protocol WSHandler: Sendable {
    func makeFrames(for client: AsyncThrowingStream<WSFrame, any Error>) async throws -> AsyncStream<WSFrame>
}

/// `MessageFrameWSHandler` manages the websocket protocol by splitting the messages from the incoming frames into a separate stream,
///  and merging the output with any frames from the output messges stream.
///
///
/// ```
///  ┌───────────┐
///  │ Frames In │
///  └───────────┘
///        │
///        │
///        ▼
///     ┌─────┐       ┌────────────┐
///     │Split│──────▶│Messages In │
///     └─────┘       └────────────┘
///        │
///        ▼
///     ┌─────┐       ┌────────────┐
///     │Merge│◀──────│Messages Out│
///     └─────┘       └────────────┘
///        │
///        ▼
///  ┌──────────┐
///  │Frames Out│
///  └──────────┘
/// ```

public struct MessageFrameWSHandler: WSHandler {

    private let handler: any WSMessageHandler
    private let frameSize: Int
    private let capacity: Int

    /// - Parameters:
    ///   - handler: Receives the client's messages and provides the messages sent to the client.
    ///   - frameSize: The largest payload of a frame sent to the client. Longer messages are split into continuation frames.
    ///   - capacity: How many client messages may wait for the handler, and how many frames may wait to be written
    ///     to the client. Past that, no more frames are read from the client until the handler catches up, and no
    ///     more messages are read from the handler until the client does. Pings and closes from the client are only
    ///     answered while frames are being read, so a handler that does not need the client's messages should still
    ///     read and discard them, or not keep its input stream at all. Once the task reading the stream is cancelled,
    ///     or the stream is released, later client messages are dropped. Each waiting message can be as large as the
    ///     server's `webSocketMaxFrameSize`.
    public init(handler: some WSMessageHandler, frameSize: Int = 16384, capacity: Int = 16) {
        precondition(capacity >= 0, "capacity must not be negative")
        self.handler = handler
        self.frameSize = frameSize
        self.capacity = capacity
    }

    public func makeFrames(for client: AsyncThrowingStream<WSFrame, any Error>) async throws -> AsyncStream<WSFrame> {
        let framesIn = WSFrameValidator.validateFrames(from: client)

        // Each handoff holds up to `capacity` elements: client frames are read
        // while fewer messages than that wait for the handler, and messages are
        // read from the handler while fewer frames wait for the connection.
        let messagesIn = AsyncHandoff<WSMessage>(capacity: capacity)
        let framesOut = AsyncHandoff<WSFrame>(capacity: capacity)

        // Once the handler's input stream ends, is cancelled or is released,
        // messagesIn is finished and later client messages are dropped, so
        // frames are still read and pings and closes are still answered.
        let input = HandlerInput(messagesIn)
        let messagesOut = try await handler.makeMessages(for: AsyncStream {
            // messagesIn is never finished with an error.
            try? await input.messages.next()
        })
        let task = Task {
            await start(framesIn: framesIn, framesOut: framesOut,
                        messagesIn: messagesIn, messagesOut: messagesOut)
        }

        let serverFrames = AsyncThrowingStream<WSFrame, any Error> { try await framesOut.next() }
        return AsyncStream.protocolFrames(from: serverFrames, onTermination: { task.cancel() })
    }

    func start<S: AsyncSequence & Sendable>(
        framesIn: S,
        framesOut: AsyncHandoff<WSFrame>,
        messagesIn: AsyncHandoff<WSMessage>,
        messagesOut: AsyncStream<WSMessage>
    ) async where S.Element == WSFrame {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    for try await frame in framesIn {
                        if frame.opcode == .close {
                            throw FrameError.closed(frame)
                        } else if let message = try makeMessage(for: frame) {
                            do {
                                try await messagesIn.send(message)
                            } catch is AsyncHandoffFinishedError {
                                // The handler no longer reads its input.
                            }
                        } else if let frame = try makeResponseFrames(for: frame) {
                            try await framesOut.send(frame)
                        }
                    }
                } catch FrameError.closed(let frame) {
                    // RFC 6455 §5.5.1: an endpoint that receives a Close frame
                    // sends one in response. Echo it and end the frames before
                    // telling the handler, so the closing handshake does not wait on it.
                    try? await framesOut.send(frame)
                    await framesOut.finish()
                    // WSFrameValidator has already checked the close payload, so
                    // makeMessage does not throw here.
                    await messagesIn.finish(with: .success(try? makeMessage(for: frame)))
                    return
                } catch is CancellationError, is AsyncHandoffFinishedError {
                } catch {
                    await framesOut.finish(throwing: error)
                }
                // Only this loop ends the handler's input, so a close it is
                // still delivering is not lost when the other loop ends first.
                await messagesIn.finish()
            }
            group.addTask {
                do {
                    for await message in messagesOut {
                        for frame in makeFrames(for: message) {
                            try await framesOut.send(frame)
                            if frame.opcode == .close {
                                return
                            }
                        }
                    }
                } catch {
                    // send throws only when cancelled or once framesOut has finished.
                }
            }
            // The connection ends with either loop, even while the other waits
            // on a handler that does not respond to cancellation. Cancelling
            // the frame loop ends the handler's input.
            await group.next()
            await framesOut.finish()
            group.cancelAll()
        }
    }

    func makeMessage(for frame: WSFrame) throws -> WSMessage? {
        switch frame.opcode {
        case .text:
            guard let string = String(data: frame.payload, encoding: .utf8) else {
                throw FrameError.invalid("Invalid UTF8 Sequence")
            }
            return .text(string)
        case .binary:
            return .data(frame.payload)
        case .close:
            return try .close(makeCloseCode(from: frame.payload))
        default:
            return nil
        }
    }

    func makeCloseCode(from payload: Data) throws -> WSCloseCode {
        guard payload.count >= 2 else {
            return .noStatusReceived
        }

        let statusCode = payload.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        guard let reason = String(data: payload.dropFirst(2), encoding: .utf8) else {
            throw FrameError.invalid("Invalid UTF8 Sequence")
        }
        return WSCloseCode(statusCode, reason: reason)
    }

    func makeResponseFrames(for frame: WSFrame) throws -> WSFrame? {
        switch frame.opcode {
        case .ping:
            var response = frame
            response.opcode = .pong
            return response
        case .pong:
            return nil
        default:
            throw FrameError.invalid("Unexpected Frame")
        }
    }

    func makeFrames(for message: WSMessage) -> [WSFrame] {
        switch message {
        case let .text(string):
            return Self.makeFrames(opcode: .text, payload: string.data(using: .utf8)!, size: frameSize)
        case let .data(data):
            return Self.makeFrames(opcode: .binary, payload: data, size: frameSize)
        case let .close(code):
            return [WSFrame.close(code: code)]
        }
    }

    static func makeFrames(opcode: WSFrame.Opcode, payload: Data, size: Int) -> [WSFrame] {
        var frames = payload.chunked(size: size).enumerated().map { idx, chunk in
            WSFrame(fin: false, opcode: idx == 0 ? opcode : .continuation, mask: nil, payload: chunk)
        }
        if let last = frames.indices.last {
            frames[last].fin = true
        }
        return frames
    }
}

extension MessageFrameWSHandler {

    enum FrameError: Error {
        case closed(WSFrame)
        case invalid(String)
    }

    // Held by the handler's input stream, which releases it when the stream
    // ends, is cancelled or is no longer referenced.
    private final class HandlerInput: Sendable {
        let messages: AsyncHandoff<WSMessage>

        init(_ messages: AsyncHandoff<WSMessage>) {
            self.messages = messages
        }

        deinit {
            Task { [messages] in await messages.finish() }
        }
    }
}

extension Collection {
    func chunked(size: Int) -> [SubSequence] {
        stride(from: 0, to: count, by: size).map { idx in
            let start = index(startIndex, offsetBy: idx)
            let end = index(start, offsetBy: size, limitedBy: endIndex) ?? endIndex
            return self[start..<end]
       }
    }
}
