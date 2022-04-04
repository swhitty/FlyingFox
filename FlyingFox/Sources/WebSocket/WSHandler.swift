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

import Foundation

public protocol WSHandler: Sendable {
    func makeFrames(for client: AsyncThrowingStream<WSFrame, Error>) async throws -> AsyncStream<WSFrame>
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

    private let handler: WSMessageHandler
    private let frameSize: Int

    public init(handler: WSMessageHandler, frameSize: Int = 16384) {
        self.handler = handler
        self.frameSize = frameSize
    }

    public func makeFrames(for client: AsyncThrowingStream<WSFrame, Error>) async throws -> AsyncStream<WSFrame> {
        let framesIn = WSFrameValidator.validateFrames(from: client)

        var messagesIn: AsyncStream<WSMessage>.Continuation!
        let messages = AsyncStream<WSMessage> {
            messagesIn = $0
        }

        let messagesOut = try await handler.makeMessages(for: messages)
        let serverFrames = AsyncThrowingStream<WSFrame, Error> { [messagesIn] continuation in
            let task = Task {
                await start(framesIn: framesIn, framesOut: continuation,
                            messagesIn: messagesIn!, messagesOut: messagesOut)
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }

        return AsyncStream.protocolFrames(from: serverFrames)
    }

    func start<S: AsyncSequence>(framesIn: S,
                                 framesOut: AsyncThrowingStream<WSFrame, Error>.Continuation,
                                 messagesIn: AsyncStream<WSMessage>.Continuation,
                                 messagesOut: AsyncStream<WSMessage>) async where S.Element == WSFrame {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    for try await frame in framesIn {
                        if let message = try makeMessage(for: frame) {
                            messagesIn.yield(message)
                        } else if let frame = try makeResponseFrames(for: frame) {
                            framesOut.yield(frame)
                        }
                    }
                } catch FrameError.closed {
                    framesOut.yield(.close(message: "Goodbye"))
                    framesOut.finish(throwing: nil)
                } catch {
                    framesOut.finish(throwing: error)
                }
            }
            group.addTask {
                for await message in messagesOut {
                    for frame in makeFrames(for: message) {
                        framesOut.yield(frame)
                    }
                }
            }
            await group.next()!
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
        default:
            return nil
        }
    }

    func makeResponseFrames(for frame: WSFrame) throws -> WSFrame? {
        switch frame.opcode {
        case .ping:
            var response = frame
            response.opcode = .pong
            return response
        case .pong:
            return nil
        case .close:
            throw FrameError.closed
        default:
            throw FrameError.invalid("Unexpected Frame")
        }
    }

    func makeFrames(for message: WSMessage) -> [WSFrame] {
        switch message {
        case .text(let string):
            return Self.makeFrames(opcode: .text, payload: string.data(using: .utf8)!, size: frameSize)
        case .data(let data):
            return Self.makeFrames(opcode: .binary, payload: data, size: frameSize)
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
        case closed
        case invalid(String)
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
