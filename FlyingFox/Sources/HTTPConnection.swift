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
    private let decoder: HTTPDecoder
    private let logger: any Logging
    let requests: HTTPRequestSequence<AsyncSocketReadSequence>

    init(socket: AsyncSocket, decoder: HTTPDecoder = .init(), logger: some Logging) {
        self.socket = socket
        self.decoder = decoder
        self.logger = logger

        let (peer, identifier) = HTTPConnection.makeIdentifer(from: socket.socket)
        self.hostname = identifier
        self.requests = HTTPRequestSequence(bytes: socket.bytes, decoder: decoder, remoteAddress: peer)
    }

    func complete() async {
        await requests.complete()
    }

    func sendResponse(_ response: HTTPResponse) async throws {
        let header = HTTPEncoder.encodeResponseHeader(response)

        switch response.payload {
        case .httpBody(let sequence):
            try await socket.write(header)
            for try await chunk in sequence {
                try await socket.write(chunk)
            }
        case .webSocket(let handler):
            try await switchToWebSocket(with: handler, response: header)
        }
    }

    func switchToWebSocket(with handler: some WSHandler, response: Data) async throws {
        let client = AsyncThrowingStream.decodingFrames(from: socket.bytes)
        let server = try await handler.makeFrames(for: client)
        try await socket.write(response)
        logger.logSwitchProtocol(self, to: "websocket")
        await requests.complete()
        for await frame in server {
            try await socket.write(WSFrameEncoder.encodeFrame(frame))
        }
    }

    func close() throws {
        try socket.close()
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

actor HTTPRequestSequence<S: AsyncBufferedSequence & Sendable>: AsyncSequence, AsyncIteratorProtocol, @unchecked Sendable where S.Element == UInt8 {
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

    static func makeIdentifer(from socket: Socket) -> (address: Socket.Address?, identifier: String) {
        guard let peer = try? socket.remotePeer() else {
            return (nil, "unknown")
        }

        if case .unix = peer, let unixAddress = try? socket.sockname() {
            return (peer, makeIdentifer(from: unixAddress))
        } else {
            return (peer, makeIdentifer(from: peer))
        }
    }

    static func makeIdentifer(from peer: Socket.Address) -> String {
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
