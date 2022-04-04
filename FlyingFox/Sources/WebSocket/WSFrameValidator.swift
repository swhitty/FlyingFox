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

        func validateFrame(_ frame: WSFrame) throws -> WSFrame? {
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
