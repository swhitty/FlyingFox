//
//  HTTPClient.swift
//  FlyingFox
//
//  Created by Simon Whitty on 8/06/2024.
//  Copyright © 2024 Simon Whitty. All rights reserved.
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

@available(*, deprecated, renamed: "HTTPClient")
public typealias _HTTPClient = HTTPClient

public struct HTTPClient: ~Copyable {

    private var _lastSocket: AsyncSocket?

    public init() { }

    public mutating func sendHTTPRequest(_ request: HTTPRequest, to address: some SocketAddress) async throws -> HTTPResponse {

        try? _lastSocket?.close()
        _lastSocket = nil

        let socket = try await AsyncSocket.connected(to: address)
        _lastSocket = socket
        try await socket.writeRequest(request)
        return try await socket.readResponse()
    }

    deinit {
        try? _lastSocket?.close()
    }
}

package extension AsyncSocket {
    func writeRequest(_ request: HTTPRequest) async throws {
        try await write(HTTPEncoder.encodeRequest(request))
    }

    func readResponse() async throws -> HTTPResponse {
        try await HTTPDecoder(sharedRequestBufferSize: 4096, sharedRequestReplaySize: 102_400).decodeResponse(from: bytes)
    }

    func writeFrame(_ frame: WSFrame) async throws {
        try await write(WSFrameEncoder.encodeFrame(frame))
    }

    func readFrame() async throws -> WSFrame {
        try await WSFrameEncoder.decodeFrame(from: bytes)
    }
}
