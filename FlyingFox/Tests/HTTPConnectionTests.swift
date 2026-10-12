//
//  HTTPConnectionTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 22/02/2022.
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
import FlyingSocks
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing

struct HTTPConnectionTests {

    @Test
    func connection_ReceivesRequest() async throws {
        let (s1, s2) = try await AsyncSocket.makePair()

        let connection = HTTPConnection(socket: s1)
        try await s2.writeString(
            """
            GET /hello/world HTTP/1.1\r
            Content-Length: 5
            \r
            Hello

            """
        )

        let request = try await connection.requests.first()
        #expect(
            await request == .make(
                method: .GET,
                version: .http11,
                path: "/hello/world",
                headers: [.contentLength: "5"],
                body: "Hello".data(using: .utf8)!
            )
        )

        try s1.close()
        try s2.close()
    }

    @Test
    func connectionRequestsAreReceived_WhileConnectionIsKeptAlive() async throws {
        let (s1, s2) = try await AsyncSocket.makePair()

        let connection = HTTPConnection(socket: s1)
        try await s2.writeString(
            """
            GET /hello HTTP/1.1\r
            Connection: Keep-Alive\r
            \r
            GET /hello HTTP/1.1\r
            Connection: Keep-Alive\r
            \r
            GET /hello HTTP/1.1\r
            Connection: close\r
            \r

            """
        )

        let count = try await connection.requests.reduce(0, { count, _ in count + 1 })
        #expect(count == 3)

        try s1.close()
        try s2.close()
    }

    @Test
    func connectionResponse_IsSent() async throws {
        let (s1, s2) = try await AsyncSocket.makePair()

        let connection = HTTPConnection(socket: s1)

        try await connection.sendResponse(
            .make(version: .http11,
                  statusCode: .gone,
                  headers: [.date: "Sun, 06 Nov 1994 08:49:37 GMT"],
                  body: "Hello World!".data(using: .utf8)!)
        )

        let response = try await s2.readString(length: 90)
        #expect(
            response == """
            HTTP/1.1 410 Gone\r
            Content-Length: 12\r
            Date: Sun, 06 Nov 1994 08:49:37 GMT\r
            \r
            Hello World!
            """
        )
    }

    @Test
    func connectionResponse_IncludesGeneratedDateHeader() async throws {
        let (s1, s2) = try await AsyncSocket.makePair()

        let connection = HTTPConnection(socket: s1)

        try await connection.sendResponse(
            .make(version: .http11,
                  statusCode: .ok,
                  body: "Hello World!".data(using: .utf8)!)
        )

        // IMF-fixdate is fixed width so the response length is deterministic.
        let response = try await s2.readString(length: 88)
        let expected = #"""
        ^HTTP/1\.1 200 OK\r\nContent-Length: 12\r\nDate: (Mon|Tue|Wed|Thu|Fri|Sat|Sun), \d{2} (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{4} \d{2}:\d{2}:\d{2} GMT\r\n\r\nHello World!$
        """#
        #expect(
            response.range(of: expected, options: .regularExpression) != nil
        )

        try s1.close()
        try s2.close()
    }

    @Test
    func connectionDisconnects_WhenErrorIsReceived() async throws {
        let (s1, s2) = try await AsyncSocket.makePair()

        try s2.close()
        let connection = HTTPConnection(socket: s1)

        let count = try await connection.requests.reduce(0, { count, _ in count + 1 })
        #expect(count == 0)

        try connection.close()
    }

    @Test
    func connectionHostName() {
        #expect(
            HTTPConnection.makeIdentifier(from: .ip4("8.8.8.8", port: 8080)) == "8.8.8.8"
        )
        #expect(
            HTTPConnection.makeIdentifier(from: .ip6("::1", port: 8080)) == "::1"
        )
        #expect(
            HTTPConnection.makeIdentifier(from: .unix("/var/sock/fox")) == "/var/sock/fox"
        )
    }

    @Test
    func webSocket_UnmaskedClientFrame_ClosesWithProtocolError() async throws {
        // RFC 6455 §5.1: "The server MUST close the connection upon receiving
        // a frame that is not masked. In this case, a server MAY send a Close
        // frame with a status code of 1002 (protocol error)."
        // Frame equality also asserts the close frame leaves the wire
        // unmasked; `sendResponse` returning proves the response loop
        // terminates — the owning `HTTPServer` then closes the socket.
        let (s1, s2) = try await AsyncSocket.makePair()
        let connection = HTTPConnection(socket: s1)

        let response = Task {
            try await connection.sendResponse(HTTPResponse(webSocket: MessageFrameWSHandler.make()))
        }

        _ = try await s2.readResponse()
        try await s2.writeFrame(.fish)

        // .close(message:) carries WSCloseCode.protocolError (1002).
        #expect(
            try await s2.readFrame() == .close(message: "Protocol Error")
        )
        try await response.value

        try s1.close()
        try s2.close()
    }

    @Test
    func webSocket_OversizedClientFrame_ClosesWithMessageTooBig() async throws {
        // RFC 6455 §7.4.1: 1009 indicates a message too big to process. The
        // frame's declared length is checked before its payload is read.
        let (s1, s2) = try await AsyncSocket.makePair()
        let connection = HTTPConnection(socket: s1, webSocketMaxFrameSize: 1024)

        let response = Task {
            try await connection.sendResponse(HTTPResponse(webSocket: MessageFrameWSHandler.make()))
        }

        _ = try await s2.readResponse()
        try await s2.writeFrame(.make(opcode: .binary, mask: .mock, payload: Data(count: 1025)))

        #expect(
            try await s2.readFrame() == .close(code: .messageTooBig)
        )
        try await response.value

        try s1.close()
        try s2.close()
    }

    @Test
    func webSocket_MaskedClientFrames_AreDeliveredToHandlerUnmasked() async throws {
        // Wire masks are consumed by `decodeClientFrame`; handlers receive
        // frames with `mask == nil` and the payload already unmasked.
        let (s1, s2) = try await AsyncSocket.makePair()
        let connection = HTTPConnection(socket: s1)

        let response = Task {
            try await connection.sendResponse(HTTPResponse(webSocket: MaskReportingWSHandler()))
        }

        _ = try await s2.readResponse()
        try await s2.writeFrame(.fish.masked())

        #expect(
            try await s2.readFrame() == .make(
                opcode: .binary,
                payload: Data([1]) + "Fish".data(using: .utf8)!
            )
        )

        response.cancel()
        try s1.close()
        try s2.close()
    }

    @Test
    func webSocket_ClientDisconnect_EndsConnectionWithoutError() async throws {
        // A peer that closes TCP without sending a Close frame ends the client
        // stream (SocketError.disconnected → nil); the handler's output then
        // finishes and the response loop completes cleanly.
        let (s1, s2) = try await AsyncSocket.makePair()
        let connection = HTTPConnection(socket: s1)

        let response = Task {
            try await connection.sendResponse(HTTPResponse(webSocket: MessageFrameWSHandler.make()))
        }

        _ = try await s2.readResponse()
        try s2.close()

        try await response.value

        try s1.close()
    }
}

private struct MaskReportingWSHandler: WSHandler {
    // Echoes each frame as binary: first byte 1 when the received frame had
    // no mask, followed by the received payload.
    func makeFrames(for client: AsyncThrowingStream<WSFrame, any Error>) async throws -> AsyncStream<WSFrame> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    for try await frame in client {
                        continuation.yield(
                            WSFrame(fin: true,
                                    opcode: .binary,
                                    mask: nil,
                                    payload: Data([frame.mask == nil ? 1 : 0]) + frame.payload)
                        )
                    }
                } catch { }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private extension HTTPConnection {
    init(socket: AsyncSocket, webSocketMaxFrameSize: Int = 16_777_216) {
        self.init(
            socket: socket,
            decoder: HTTPDecoder.make(),
            logger: .disabled,
            webSocketMaxFrameSize: webSocketMaxFrameSize
        )
    }
}

extension AsyncSequence {
    func first() async throws -> Element {
        guard let next = try await first(where: { _ in true }) else {
            throw AsyncSequenceError("Premature termination")
        }
        return next
    }
}

extension HTTPRequest {
    static func ==(lhs: HTTPRequest, rhs: HTTPRequest) async -> Bool {
        let lhsData = try? await lhs.bodyData
        let rhsData = try? await rhs.bodyData
        guard let lhsData, let rhsData else { return false }
        return lhs.method == rhs.method &&
               lhs.version == rhs.version &&
               lhs.path == rhs.path &&
               lhs.query == rhs.query &&
               lhs.headers == rhs.headers &&
               lhsData == rhsData
    }
}
