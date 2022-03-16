//
//  WSFrameEncoderTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 16/03/2022.
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

final class WSFrameEncoderTests: XCTestCase {

    func testEncodeFrame0() {
        var frame = WSFrame.make(fin: false,
                                 rsv1: false,
                                 rsv2: false,
                                 rsv3: false,
                                 opcode: .continuation,
                                 mask: nil)

        XCTAssertEqual(
            WSFrameEncoder.encodeFrame0(frame),
            0b00000000
        )

        frame.fin = true
        XCTAssertEqual(
            WSFrameEncoder.encodeFrame0(frame),
            0b10000000
        )
        frame.rsv1 = true
        XCTAssertEqual(
            WSFrameEncoder.encodeFrame0(frame),
            0b11000000
        )

        frame.rsv2 = true
        XCTAssertEqual(
            WSFrameEncoder.encodeFrame0(frame),
            0b11100000
        )

        frame.rsv3 = true
        XCTAssertEqual(
            WSFrameEncoder.encodeFrame0(frame),
            0b11110000
        )
        frame.opcode = .text
        XCTAssertEqual(
            WSFrameEncoder.encodeFrame0(frame),
            0b11110001
        )
        frame.opcode = .pong
        XCTAssertEqual(
            WSFrameEncoder.encodeFrame0(frame),
            0b11111010
        )
    }

    func testEncodeFrame1() {
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(0b00011001, isMask: false),
            [0b00011001]
        )
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(0b00011001, isMask: true),
            [0b10011001]
        )
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(Int(UInt16.max), isMask: false).first,
            0b01111110
        )
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(Int(UInt16.max), isMask: true).first,
            0b11111110
        )
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(Int(UInt16.max) + 1, isMask: false).first,
            0b01111111
        )
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(Int(UInt16.max) + 1, isMask: true).first,
            0b11111111
        )
    }

    func testEncodeLength() {
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(125, isMask: false).count,
            1
        )
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(126, isMask: false).count,
            3
        )
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(Int(UInt16.max), isMask: false).count,
            3
        )
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(Int(UInt16.max) + 1, isMask: false).count,
            9
        )
    }

    func testEncodePayload() {
        XCTAssertEqual(
            WSFrameEncoder.encodePayload(Data([0x01, 0x02]), mask: nil),
            Data([0x01, 0x02])
        )
        XCTAssertEqual(
            WSFrameEncoder.encodePayload(Data([0x01, 0x02, 0x03, 0x04]),
                                         mask: .init(m1: 0xFF, m2: 0xFF, m3: 0xFF, m4: 0xFF)),
            Data([0xFF, 0xFF, 0xFF, 0xFF, 0xFE, 0xFD, 0xFC, 0xFB])
        )
    }

    func testEncodeFrame() {
        let frame = WSFrame.make(fin: true,
                                 opcode: .text,
                                 payload: "Abc".data(using: .utf8)!)

        XCTAssertEqual(
            WSFrameEncoder.encodeFrame(frame),
            Data([
                0b10000001, 3, .ascii("A"), .ascii("b"), .ascii("c")
            ])
        )
    }

    func testDecodeFrame0() {
        XCTAssertEqual(
            WSFrameEncoder.decodeFrame(from: 0b10000000),
            .make(fin: true, rsv1: false, rsv2: false, rsv3: false, opcode: .continuation)
        )
        XCTAssertEqual(
            WSFrameEncoder.decodeFrame(from: 0b01000000),
            .make(fin: false, rsv1: true, rsv2: false, rsv3: false, opcode: .continuation)
        )
        XCTAssertEqual(
            WSFrameEncoder.decodeFrame(from: 0b10100000),
            .make(fin: true, rsv1: false, rsv2: true, rsv3: false, opcode: .continuation)
        )
        XCTAssertEqual(
            WSFrameEncoder.decodeFrame(from: 0b11110001),
            .make(fin: true, rsv1: true, rsv2: true, rsv3: true, opcode: .text)
        )
        XCTAssertEqual(
            WSFrameEncoder.decodeFrame(from: 0b11110010),
            .make(fin: true, rsv1: true, rsv2: true, rsv3: true, opcode: .binary)
        )
        XCTAssertEqual(
            WSFrameEncoder.decodeFrame(from: 0b11111000),
            .make(fin: true, rsv1: true, rsv2: true, rsv3: true, opcode: .close)
        )
        XCTAssertEqual(
            WSFrameEncoder.decodeFrame(from: 0b11111001),
            .make(fin: true, rsv1: true, rsv2: true, rsv3: true, opcode: .ping)
        )

        XCTAssertEqual(
            WSFrameEncoder.decodeFrame(from: 0b11111010),
            .make(fin: true, rsv1: true, rsv2: true, rsv3: true, opcode: .pong)
        )
    }
}

private extension UInt8 {
    static func ascii(_ char: Character) -> Self {
        char.asciiValue!
    }
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
}
