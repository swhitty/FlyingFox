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

import FlyingSocks
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
            contentsOf: encodeLength(frame.payload.count, hasMask: frame.mask != nil)
        )
        data.append(
            contentsOf: encodePayload(frame.payload, mask: frame.mask)
        )
        return data
    }

    static func decodeFrame(from bytes: some AsyncBufferedSequence<UInt8>) async throws -> WSFrame {
        var frame = try await decodeFrame(from: bytes.take())
        let (length, mask) = try await decodeLengthMask(from: bytes)
        frame.payload = try await decodePayload(from: bytes, length: length, mask: mask)
        return frame
    }

    static func encodeFrame0(_ frame: WSFrame) -> UInt8 {
        var byte: UInt8 = frame.opcode.rawValue
        byte |= frame.fin.byte << 7
        byte |= frame.rsv1.byte << 6
        byte |= frame.rsv2.byte << 5
        byte |= frame.rsv3.byte << 4
        return byte
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

    static func encodeLength(_ length: Int, hasMask: Bool) -> [UInt8] {
        if length <= 125 {
            return [hasMask.byte << 7 | UInt8(length)]
        } else if length <= UInt16.max {
            return [hasMask.byte << 7 | UInt8(126),
                    UInt8(length >> 8 & 0xFF),
                    UInt8(length >> 0 & 0xFF)]
        } else {
            let byte0 = UInt8(hasMask.byte << 7 | UInt8(127))
            let byte1 = UInt8(length >> 56 & 0xFF)
            let byte2 = UInt8(length >> 48 & 0xFF)
            let byte3 = UInt8(length >> 40 & 0xFF)
            let byte4 = UInt8(length >> 32 & 0xFF)
            let byte5 = UInt8(length >> 24 & 0xFF)
            let byte6 = UInt8(length >> 16 & 0xFF)
            let byte7 = UInt8(length >> 8 & 0xFF)
            let byte8 = UInt8(length & 0xFF)
            return [
                byte0, byte1, byte2, byte3, byte4,
                byte5, byte6, byte7, byte8
            ]
        }
    }

    static func decodePayload(from bytes: some AsyncBufferedSequence<UInt8>, length: Int, mask: WSFrame.Mask?) async throws -> Data {
        var iterator = bytes.makeAsyncIterator()
        guard var payload = try await iterator.nextBuffer(count: length) else {
            throw SocketError.disconnected
        }
        if let mask = mask {
            for idx in payload.indices {
                payload[idx] ^= mask[idx % 4]
            }
        }
        return Data(payload)
    }

    static func decodeLengthMask(from bytes: some AsyncBufferedSequence<UInt8>) async throws -> (length: Int, mask: WSFrame.Mask?) {
        let byte0 = try await bytes.take()
        let hasMask = byte0 & 0b10000000 == 0b10000000
        let length0 = byte0 & 0b01111111
        switch length0 {
        case 0...125:
            return try await (Int(length0), hasMask ? decodeMask(from: bytes) : nil)
        case 126:
            let length = try await UInt16(bytes.take()) |
                                   UInt16(bytes.take()) << 8
            return try await (Int(length), hasMask ? decodeMask(from: bytes) : nil)
        default:
            var length = try await UInt64(bytes.take())
            length |= try await UInt64(bytes.take()) << 8
            length |= try await UInt64(bytes.take()) << 16
            length |= try await UInt64(bytes.take()) << 24
            length |= try await UInt64(bytes.take()) << 32
            length |= try await UInt64(bytes.take()) << 40
            length |= try await UInt64(bytes.take()) << 48
            length |= try await UInt64(bytes.take()) << 56

            guard length <= Int.max else {
                throw Error("Length is greater than Int.max")
            }
            return try await (Int(length), hasMask ? decodeMask(from: bytes) : nil)
        }
    }

    static func decodeMask(from bytes: some AsyncBufferedSequence<UInt8>) async throws -> WSFrame.Mask {
        try await WSFrame.Mask(m1: bytes.take(),
                               m2: bytes.take(),
                               m3: bytes.take(),
                               m4: bytes.take())
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

extension WSFrameEncoder {

    struct Error: LocalizedError {
        var errorDescription: String?

        init(_ description: String) {
            self.errorDescription = description
        }
    }
}

private extension Bool {
    var byte: UInt8 { self ? 1 : 0 }
}

private extension WSFrame.Mask {
    subscript(_ idx: Int) -> UInt8 {
        get {
            precondition(idx >= 0 && idx < 4)
            switch idx {
            case 0:
                return m1
            case 1:
                return m2
            case 2:
                return m3
            default:
                return m4
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
