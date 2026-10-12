//
//  WSFrameValidator.swift
//  FlyingFox
//
//  Created by Simon Whitty on 19/03/2022.
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

struct WSFrameValidator: Sendable {

    // Buffer/Group any continuation frames from AsyncSequence<WSFrame>
    static func validateFrames<S: AsyncSequence>(from client: S) -> AsyncThrowingCompactMapSequence<S, WSFrame> where S.Element == WSFrame {
        let buffer = Validator()
        return client.compactMap(buffer.validateFrame)
    }

    private final class Validator: @unchecked Sendable {

        private var last: WSFrame?

        @Sendable
        func validateFrame(_ frame: WSFrame) throws -> WSFrame? {
            switch frame.opcode {
            case .ping, .pong, .close:
                // RFC 6455 §5.5: control frame payload MUST be ≤ 125 bytes.
                guard frame.payload.count <= 125 else {
                    throw Error("Control frame payload exceeds 125 bytes")
                }
            default:
                break
            }

            if frame.opcode == .close {
                try validateClosePayload(frame.payload)
            }

            if frame.opcode == .continuation {
                try appendContinuation(frame)
                guard let last = last, frame.fin else {
                    return nil
                }
                self.last = nil
                return last
            }

            guard frame.fin else {
                try beginContinuation(frame)
                return nil
            }

            return frame
        }

        func beginContinuation(_ continuation: WSFrame) throws {
            guard last == nil else {
                throw Error("Unexpected Incomplete")
            }
            switch continuation.opcode {
            case .pong, .ping, .close:
                throw Error("Unsupport Control Continuation")
            default:
                last = continuation
            }
        }

        func appendContinuation(_ continuation: WSFrame) throws {
            guard last != nil else {
                throw Error("Unexpected Continuation")
            }
            last!.fin = continuation.fin
            last!.payload.append(continuation.payload)
        }

        // RFC 6455 §5.5.1: a close payload is empty, or a 2 byte status code
        // followed by an optional UTF-8 reason.
        func validateClosePayload(_ payload: Data) throws {
            guard !payload.isEmpty else { return }
            guard payload.count >= 2 else {
                throw Error("Close frame payload must contain a status code")
            }
            let code = UInt16(payload[payload.startIndex]) << 8 | UInt16(payload[payload.startIndex + 1])
            guard WSFrameValidator.isValidCloseCode(code) else {
                throw Error("Invalid close status code \(code)")
            }
            guard String(data: payload.dropFirst(2), encoding: .utf8) != nil else {
                throw Error("Close frame reason is not valid UTF-8")
            }
        }
    }

    // RFC 6455 §7.4: codes an endpoint may send. 1005, 1006 and 1015 are
    // reserved for local use, 1004 and 1016–2999 for future revisions.
    static func isValidCloseCode(_ code: UInt16) -> Bool {
        switch code {
        case 1000...1003, 1007...1014, 3000...4999:
            return true
        default:
            return false
        }
    }
}

extension WSFrameValidator {

    struct Error: LocalizedError {
        var errorDescription: String?

        init(_ description: String) {
            self.errorDescription = description
        }
    }
}
