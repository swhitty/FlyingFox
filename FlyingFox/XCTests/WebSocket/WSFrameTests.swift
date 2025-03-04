//
//  WSFrameTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 17/03/2022.
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
import Foundation
import XCTest

final class WSFrameTests: XCTestCase {

    func testCloseFrame() {
        XCTAssertEqual(
            WSFrame.close(),
            .make(fin: true,
                  opcode: .close,
                  mask: nil,
                  payload: Data([0x03, 0xE8]))
        )
        XCTAssertEqual(
            WSFrame.close(mask: .mock),
            .make(fin: true,
                  opcode: .close,
                  mask: .mock,
                  payload: Data([0x03, 0xE8]))
        )
        XCTAssertEqual(
            WSFrame.close(message: "Err"),
            .make(fin: true,
                  opcode: .close,
                  mask: nil,
                  payload: Data([0x03, 0xEA, .ascii("E"), .ascii("r"), .ascii("r")]))
        )
        XCTAssertEqual(
            WSFrame.close(message: "Err", mask: .mock),
            .make(fin: true,
                  opcode: .close,
                  mask: .mock,
                  payload: Data([0x03, 0xEA, .ascii("E"), .ascii("r"), .ascii("r")]))
        )
        XCTAssertEqual(
            WSFrame.close(code: WSCloseCode(4999), message: "Err"),
            .make(
                fin: true,
                opcode: .close,
                mask: nil,
                payload: Data([0x13, 0x87, .ascii("E"), .ascii("r"), .ascii("r")])
            )
        )
        XCTAssertEqual(
            WSFrame.close(code: WSCloseCode(4999), message: "Err", mask: .mock),
            .make(
                fin: true,
                opcode: .close,
                mask: .mock,
                payload: Data([0x13, 0x87, .ascii("E"), .ascii("r"), .ascii("r")])
            )
        )
    }
}

extension UInt8 {
    static func ascii(_ char: Character) -> Self {
        char.asciiValue!
    }
}

extension WSFrame.Mask {
    static let mock = WSFrame.Mask(m1: 0x1, m2: 0x2, m3: 0x3, m4: 0x4)
}

extension WSFrame {

    static func make(fin: Bool = true,
                     rsv1: Bool = false,
                     rsv2: Bool = false,
                     rsv3: Bool = false,
                     opcode: Opcode = .text,
                     mask: Mask? = nil,
                     payload: Data = Data()) -> Self {
        WSFrame(fin: fin,
                rsv1: rsv1,
                rsv2: rsv2,
                rsv3: rsv3,
                opcode: opcode,
                mask: mask,
                payload: payload)
    }

    static func make(fin: Bool = true,
                     isContinuation: Bool = false,
                     text: String) -> Self {
        WSFrame(fin: fin,
                rsv1: false,
                rsv2: false,
                rsv3: false,
                opcode: isContinuation ? .continuation : .text,
                mask: nil,
                payload: text.data(using: .utf8)!)
    }

    static func makeTextFrames(_ payload: String, maxCharacters: Int) -> [WSFrame] {
        var messages = payload.chunked(size: maxCharacters).enumerated().map { idx, substring in
            WSFrame.make(fin: false, isContinuation: idx != 0, text: String(substring))
        }

        if let last = messages.indices.last {
            messages[last].fin = true
        }
        return messages
    }
}
