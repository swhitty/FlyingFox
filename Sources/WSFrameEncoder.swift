//
//  WSFrameEncoder.swift
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

import Foundation

///```
///
///    0                   1                   2                   3
///    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
///   +-+-+-+-+-------+-+-------------+-------------------------------+
///   |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
///   |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
///   |N|V|V|V|       |S|             |   (if payload len==126/127)   |
///   | |1|2|3|       |K|             |                               |
///   +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
///   |     Extended payload length continued, if payload len == 127  |
///   + - - - - - - - - - - - - - - - +-------------------------------+
///   |                               |Masking-key, if MASK set to 1  |
///   +-------------------------------+-------------------------------+
///   | Masking-key (continued)       |          Payload Data         |
///   +-------------------------------- - - - - - - - - - - - - - - - +
///   :                     Payload Data continued ...                :
///   + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
///   |                     Payload Data continued ...                |
///   +---------------------------------------------------------------+
///```
///
struct WSFrameEncoder {

    static func encodeFrame(_ frame: WSFrame) -> Data {
        var data = Data([encodeFrame0(frame)])
        data.append(
            contentsOf: encodeLength(frame.payload.count, isMask: frame.mask != nil)
        )
        data.append(
            contentsOf: encodePayload(frame.payload, mask: frame.mask)
        )
        return data
    }

    static func decodeFrame<S>(from bytes: S) async throws -> WSFrame where S: ChunkedAsyncSequence, S.Element == UInt8 {
        let frame = try await decodeFrame(from: bytes.take())
        return frame
    }

    static func encodeFrame0(_ frame: WSFrame) -> UInt8 {
        frame.fin.byte << 7 |
        frame.rsv1.byte << 6 |
        frame.rsv2.byte << 5 |
        frame.rsv3.byte << 4 |
        frame.opcode.rawValue
    }

    static func decodeFrame(from byte0: UInt8) -> WSFrame {
        WSFrame(fin:  byte0 & 0b10000000 == 0b10000000,
                rsv1: byte0 & 0b01000000 == 0b01000000,
                rsv2: byte0 & 0b00100000 == 0b00100000,
                rsv3: byte0 & 0b00010000 == 0b00010000,
                opcode: WSFrame.Opcode(byte0 & 0b00001111),
                mask: nil,
                payload: Data())
    }

    static func decodeOpcode(from byte0: UInt8) -> WSFrame.Opcode {
        .text
    }

    static func encodeLength(_ length: Int, isMask: Bool) -> [UInt8] {
        if length <= 125 {
            return [isMask.byte << 7 | UInt8(length)]
        } else if length <= UInt16.max {
            return [isMask.byte << 7 | UInt8(126),
                    UInt8(length >> 8 & 0xFF),
                    UInt8(length >> 0 & 0xFF)]
        } else {
            return [isMask.byte << 7 | UInt8(127),
                    UInt8(length >> 56 & 0xFF),
                    UInt8(length >> 48 & 0xFF),
                    UInt8(length >> 40 & 0xFF),
                    UInt8(length >> 32 & 0xFF),
                    UInt8(length >> 24 & 0xFF),
                    UInt8(length >> 16 & 0xFF),
                    UInt8(length >> 8 & 0xFF),
                    UInt8(length >> 0 & 0xFF)]
        }
    }

    static func encodePayload(_ payload: Data, mask: WSFrame.Mask?) -> Data {
        guard let mask = mask else { return payload }
        var data = Data([
            mask.m1, mask.m2, mask.m3, mask.m4
        ])

        for (idx, byte) in payload.enumerated() {
            data.append(byte ^ mask[idx % 4])
        }
        return data
    }
}

private extension Bool {
    var byte: UInt8 { self ? 1 : 0 }
}

private extension WSFrame.Mask {
    subscript(_ idx: Int) -> UInt8 {
        get {
            switch idx {
            case 0:
                return m1
            case 1:
                return m2
            case 2:
                return m3
            case 3:
                return m4
            default:
                preconditionFailure("invalid index")
            }
        }
    }
}


extension AsyncSequence where Element == UInt8 {

    func take() async throws -> UInt8 {
        var iterator = makeAsyncIterator()
        guard let next = try await iterator.next() else {
            throw SocketError.disconnected
        }
        return next
    }
}
