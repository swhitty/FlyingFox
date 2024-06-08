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

@_spi(Private) @testable import FlyingFox
@testable import FlyingSocks
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
            WSFrameEncoder.encodeLength(0b00011001, hasMask: false),
            [0b00011001]
        )
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(0b00011001, hasMask: true),
            [0b10011001]
        )
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(Int(UInt16.max), hasMask: false).first,
            0b01111110
        )
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(Int(UInt16.max), hasMask: true).first,
            0b11111110
        )
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(Int(UInt16.max) + 1, hasMask: false).first,
            0b01111111
        )
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(Int(UInt16.max) + 1, hasMask: true).first,
            0b11111111
        )
    }

    func testEncodeLength() {
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(125, hasMask: false).count,
            1
        )
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(126, hasMask: false).count,
            3
        )
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(Int(UInt16.max), hasMask: false).count,
            3
        )
        XCTAssertEqual(
            WSFrameEncoder.encodeLength(Int(UInt16.max) + 1, hasMask: false).count,
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

    func testDecodeFrame() async {
        await AsyncAssertEqual(
            try await WSFrameEncoder.decodeFrame(0b10000001, 3, .ascii("A"), .ascii("b"), .ascii("c")),
            .make(fin: true,
                  opcode: .text,
                  payload: "Abc".data(using: .utf8)!)
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

    func testDecodeLength() async {
        await AsyncAssertEqual(
            try await WSFrameEncoder.decodeLength(0x01),
            1
        )
        await AsyncAssertEqual(
            try await WSFrameEncoder.decodeLength(0x7D),
            125
        )
        await AsyncAssertEqual(
            try await WSFrameEncoder.decodeLength(0x7E, 0x00, 0xFF),
            0xFF00
        )
        await AsyncAssertEqual(
            try await WSFrameEncoder.decodeLength(0x7E, 0xFF, 0x00),
            0x00FF
        )
        await AsyncAssertEqual(
            try await WSFrameEncoder.decodeLength(0x7E, 0xFF, 0xFF),
            0xFFFF
        )
        await AsyncAssertEqual(
            try await WSFrameEncoder.decodeLength(0x7F, 0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA, 0x99, 0x00),
            0x0099AABBCCDDEEFF
        )
    }

    func testDecodeInvalidLength_ThrowsError() async {
        await AsyncAssertThrowsError(
            try await WSFrameEncoder.decodeLength(0x7E),
            of: SocketError.self
        ) { XCTAssertEqual($0, .disconnected) }

        await AsyncAssertThrowsError(
            try await WSFrameEncoder.decodeLength(0x7F, 0xFF, 0xFF, 0xFF),
            of: SocketError.self
        ) { XCTAssertEqual($0, .disconnected) }
        await AsyncAssertThrowsError(
            try await WSFrameEncoder.decodeLength(0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF),
            of: WSFrameEncoder.Error.self
        )
    }

    func testDecodeMask() async {
        await AsyncAssertEqual(
            try await WSFrameEncoder.decodeMask(0xF0, 0x01, 0x02, 0x03, 0x04),
            .init(m1: 0x01, m2: 0x02, m3: 0x03, m4: 0x04)
        )
        await AsyncAssertEqual(
            try await WSFrameEncoder.decodeMask(0x70),
            nil
        )
        await AsyncAssertEqual(
            try await WSFrameEncoder.decodeMask(0xFE, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04),
            .init(m1: 0x01, m2: 0x02, m3: 0x03, m4: 0x04)
        )
        await AsyncAssertEqual(
            try await WSFrameEncoder.decodeMask(0x7E, 0x00, 0x00),
            nil
        )
        await AsyncAssertEqual(
            try await WSFrameEncoder.decodeMask(0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04),
            .init(m1: 0x01, m2: 0x02, m3: 0x03, m4: 0x04)
        )
        await AsyncAssertEqual(
            try await WSFrameEncoder.decodeMask(0x7F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00),
            nil
        )
    }

    func testDecodeInvalidMask_ThrowsError() async {
        await AsyncAssertThrowsError(
            try await WSFrameEncoder.decodeMask(0xFD, 0x01, 0x02),
            of: SocketError.self
        ) { XCTAssertEqual($0, .disconnected) }

        await AsyncAssertThrowsError(
            try await WSFrameEncoder.decodeMask(0xFE, 0x00, 0x00, 0x01, 0x02),
            of: SocketError.self
        ) { XCTAssertEqual($0, .disconnected) }
        await AsyncAssertThrowsError(
            try await WSFrameEncoder.decodeMask(0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02),
            of: SocketError.self
        ) { XCTAssertEqual($0, .disconnected) }
    }

    func testDecodePayload() async {
        await AsyncAssertEqual(
            try await WSFrameEncoder.decodePayload(length: 2, mask: nil, 0x01, 0x02, 0x03, 0x04),
            Data([0x01, 0x02])
        )
        await AsyncAssertEqual(
            try await WSFrameEncoder.decodePayload(length: 4, mask: nil, 0x01, 0x02, 0x03, 0x04),
            Data([0x01, 0x02, 0x03, 0x04])
        )
        await AsyncAssertEqual(
            try await WSFrameEncoder.decodePayload(length: 2, mask: (0xFF, 0xFF, 0xFF, 0xFF), 0x00, 0x01, 0x02, 0x03),
            Data([0xFF, 0xFE])
        )
        await AsyncAssertEqual(
            try await WSFrameEncoder.decodePayload(length: 2, mask: nil, 0x01, 0x02, 0x03, 0x04),
            Data([0x01, 0x02])
        )
        await AsyncAssertEqual(
            try await WSFrameEncoder.decodePayload(length: 4, mask: (0xFF, 0xFF, 0xFF, 0xFF), 0x00, 0x01, 0x02, 0x03),
            Data([0xFF, 0xFE, 0xFD, 0xFC])
        )
    }

    func testDecodeInvalidPayload_ThrowsError() async {
        await AsyncAssertThrowsError(
            try await WSFrameEncoder.decodePayload(length: 10, mask: nil, 0x01, 0x02, 0x03, 0x04),
            of: SocketError.self
        ) { XCTAssertEqual($0, .disconnected) }
    }

    func debug_testWebSocketConnectionToVI() async throws {
        let addr = try Socket.makeAddressINET(fromIP4: "192.236.209.31", port: 80)
        let socket = try await AsyncSocket.connected(to: addr)
        defer { try? socket.close() }

        let key = WebSocketHTTPHandler.makeSecWebSocketKeyValue()

        var request = HTTPRequest.make(path: "/mirror")
        request.headers[.host] = "ws.vi-server.org"
        request.headers[.upgrade] = "websocket"
        request.headers[.connection] = "Upgrade"
        request.headers[.webSocketVersion] = "13"
        request.headers[.webSocketKey] = key

        try await socket.writeRequest(request)
        let response = try await socket.readResponse()

        XCTAssertEqual(
            response.headers[.webSocketAccept],
            WebSocketHTTPHandler.makeSecWebSocketAcceptValue(for: key)
        )

        var frame = WSFrame.make(fin: true, opcode: .text, mask: .mock, payload: "FlyingFox".data(using: .utf8)!)
        try await socket.writeFrame(frame)

        frame = WSFrame.make(fin: true, opcode: .text, mask: .mock, payload: "FlyingSox".data(using: .utf8)!)
        try await socket.writeFrame(frame)

        frame = WSFrame.close(mask: .mock)
        try await socket.writeFrame(frame)
    }
}

private extension WSFrameEncoder {

    static func decodeFrame(_ bytes: UInt8...) async throws -> WSFrame {
        try await decodeFrame(from: ConsumingAsyncSequence(bytes))
    }

    static func decodeLength(_ bytes: UInt8...) async throws -> Int {
        try await decodeLengthMask(bytes).length
    }

    static func decodeMask(_ bytes: UInt8...) async throws -> WSFrame.Mask? {
        try await decodeLengthMask(bytes).mask
    }

    static func decodePayload(length: Int, mask: (UInt8, UInt8, UInt8, UInt8)?, _ bytes: UInt8...) async throws -> Data {
        try await decodePayload(from: ConsumingAsyncSequence(bytes), length: length, mask: mask.map(WSFrame.Mask.init))
    }

    static func decodeLengthMask(_ bytes: [UInt8]) async throws -> (length: Int, mask: WSFrame.Mask?) {
        try await decodeLengthMask(from: ConsumingAsyncSequence(bytes))
    }
}
