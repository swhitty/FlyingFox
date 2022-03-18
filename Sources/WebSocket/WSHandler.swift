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

public protocol WSHandler: Sendable {
    func makeSocketFrames(for request: WSFrameSequence) async throws -> WSFrameSequence
}

public struct WebSocketEchoHandler: WSHandler {

    public func makeSocketFrames(for request: WSFrameSequence) async throws -> WSFrameSequence {
        WSFrameSequence(request.compactMap(Self.makeEchoFrame))
    }

    private static func makeEchoFrame(for frame: WSFrame) -> WSFrame? {
        var response = frame
        response.mask = nil

        switch frame.opcode {
        case .ping:
            response.opcode = .pong
            return response
        case .pong:
            return nil
        case .close:
            return .close(message: "Goodbye")
        default:
            return response
        }
    }
}
