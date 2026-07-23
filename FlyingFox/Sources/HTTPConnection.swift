//
//  HTTPConnection.swift
//  FlyingFox
//
//  Created by Simon Whitty on 13/02/2022.
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

struct HTTPConnection: Sendable {

    let hostname: String
    private let socket: AsyncSocket
    private let bytes: AsyncBufferingSequence<AsyncSocketReadSequence>
    private let decoder: HTTPDecoder
    private let logger: any Logging
    let requests: HTTPRequestSequence<AsyncBufferingSequence<AsyncSocketReadSequence>>

    init(socket: AsyncSocket, decoder: HTTPDecoder, logger: some Logging) {
        self.socket = socket
        self.decoder = decoder
        self.logger = logger

        // Wrap socket.bytes once per connection so header parsing, body
        // reading, and any subsequent protocol upgrade all share a single
        // 4 KB read buffer. Without this, the HTTP decoder pulls one byte
        // per syscall through `iterator.next()` while parsing the status
        // line and headers.
        let bytes = AsyncBufferingSequence(socket.bytes)
        let (peer, identifier) = HTTPConnection.makeIdentifier(from: socket.socket)
        self.hostname = identifier
        self.bytes = bytes
        self.requests = HTTPRequestSequence(bytes: bytes, decoder: decoder, remoteAddress: peer)
    }

    func complete() async {
        await requests.complete()
    }

    func sendResponse(_ response: HTTPResponse) async throws {
        let header = HTTPEncoder.encodeResponseHeader(response)

        switch response.payload {
        case .httpBody(let sequence):
            try await socket.write(header)
            var sent = 0
            for try await chunk in sequence {
                do {
                    try await socket.write(chunk)
                    sent += chunk.count
                } catch {
                    let total = sequence.count.map(String.init) ?? "unknown"
                    throw Error("\(error.localizedDescription), sent: \(sent)/\(total).")
                }
            }
        case .webSocket(let handler):
            try await switchToWebSocket(with: handler, response: header)
        }
    }

    func switchToWebSocket(with handler: some WSHandler, response: Data) async throws {
        let (violations, violationsIn) = AsyncStream<Void>.makeStream()

        // Reuse the connection-wide buffered stream so any bytes already
        // pulled past the upgrade request remain available to the WS framer.
        let bytes = self.bytes
        let client = AsyncThrowingStream<WSFrame, any Swift.Error> {
            do {
                var frame = try await WSFrameEncoder.decodeFrame(from: bytes)
                // RFC 6455 §5.1: "a client MUST mask all frames that it sends
                // to the server. ... The server MUST close the connection upon
                // receiving a frame that is not masked."
                guard frame.mask != nil else {
                    violationsIn.yield(())
                    return nil
                }
                // Handlers never see wire masks, so frames they echo back are
                // safe to send unchanged.
                frame.mask = nil
                return frame
            } catch SocketError.disconnected, is SequenceTerminationError {
                return nil
            }
        }

        let server = try await handler.makeFrames(for: client)
        try await socket.write(response)
        logger.logSwitchProtocol(self, to: "websocket")
        await requests.complete()
        try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask {
                // Finishing `violations` on every exit — including a write
                // error — guarantees the monitor task below always completes
                // once output ends.
                defer { violationsIn.finish() }
                for await frame in server {
                    // RFC 6455 §5.1: "A server MUST NOT mask any frames that
                    // it sends to the client."
                    var frame = frame
                    frame.mask = nil
                    try await socket.write(WSFrameEncoder.encodeFrame(frame))
                }
                return false
            }
            group.addTask {
                for await _ in violations {
                    return true
                }
                return false
            }

            var isViolation = try await group.next() ?? false
            if isViolation {
                // Stop and drain the output task before touching the socket
                // so the close frame cannot interleave with another write.
                group.cancelAll()
                try? await group.waitForAll()
            } else if let second = try await group.next() {
                isViolation = second
            }
            if isViolation {
                // RFC 6455 §5.1: a server "MAY send a Close frame with a
                // status code of 1002 (protocol error)" and §7.1.7: "An
                // endpoint SHOULD send a Close frame with an appropriate
                // status code before closing the underlying connection."
                // Throwing then fails the connection regardless of handler
                // behaviour.
                try? await socket.write(WSFrameEncoder.encodeFrame(.close(code: .protocolError)))
                throw Error("Unmasked WebSocket frame received")
            }
        }
    }

    func close() throws {
        try socket.close()
    }

    struct Error: LocalizedError {
        var errorDescription: String?

        init(_ description: String) {
            self.errorDescription = description
        }
    }
}

extension HTTPConnection: Hashable {

    static func == (lhs: HTTPConnection, rhs: HTTPConnection) -> Bool {
        lhs.socket.socket.file == rhs.socket.socket.file
    }

    func hash(into hasher: inout Hasher) {
        socket.socket.file.hash(into: &hasher)
    }
}

actor HTTPRequestSequence<S: AsyncBufferedSequence & Sendable>: AsyncSequence, AsyncIteratorProtocol where S.Element == UInt8 {
    typealias Element = HTTPRequest
    private let bytes: S
    private let remoteAddress: HTTPRequest.Address?
    private let decoder: HTTPDecoder

    private var isComplete: Bool
    private var task: Task<Element, any Error>?

    init(bytes: S, decoder: HTTPDecoder, remoteAddress: Socket.Address?) {
        self.bytes = bytes
        self.decoder = decoder
        self.remoteAddress = remoteAddress.map(HTTPRequest.Address.make)
        self.isComplete = false
    }

    fileprivate func complete() {
        isComplete = true
        task?.cancel()
    }

    nonisolated func makeAsyncIterator() -> HTTPRequestSequence { self }

    func next() async throws -> HTTPRequest? {
        guard !isComplete else { return nil }

        do {
            let task = Task { try await decoder.decodeRequest(from: bytes) }
            self.task = task
            defer { self.task = nil }
            var request = try await task.getValue(cancelling: .whenParentIsCancelled)
            request.remoteAddress = remoteAddress
            if !request.shouldKeepAlive {
                isComplete = true
            }
            return request
        } catch SocketError.disconnected, is SequenceTerminationError {
            return nil
        } catch {
            throw error
        }
    }
}

extension HTTPConnection {

    static func makeIdentifier(from socket: Socket) -> (address: Socket.Address?, identifier: String) {
        guard let peer = try? socket.remotePeer() else {
            return (nil, "unknown")
        }

        if case .unix = peer, let unixAddress = try? socket.sockname() {
            return (peer, makeIdentifier(from: unixAddress))
        } else {
            return (peer, makeIdentifier(from: peer))
        }
    }

    static func makeIdentifier(from peer: Socket.Address) -> String {
        switch peer {
        case .ip4(let address, port: _):
            return address
        case .ip6(let address, port: _):
            return address
        case .unix(let path):
            return path
        }
    }
}
