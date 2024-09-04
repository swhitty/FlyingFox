//
//  SocketTests.swift
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

@testable import FlyingSocks
import Foundation
import Testing

struct SocketTests {

    @Test
    func socketEvents() {
        let events: Set<Socket.Event> = [.read, .write]

        #expect(
            "\(events)".contains("read")
        )
        #expect(
            "\(events)".contains("write")
        )
    }

    @Test
    func socketReads_DataThatIsSent() throws {
        let (s1, s2) = try Socket.makeNonBlockingPair()

        let data = Data([10, 20])
        _ = try s1.write(data, from: data.startIndex)

        #expect(try s2.read() == 10)
        #expect(try s2.read() == 20)
    }

    @Test
    func socketRead_ThrowsBlocked_WhenNoDataIsAvailable() throws {
        let (s1, s2) = try Socket.makeNonBlockingPair()

        #expect(throws: SocketError.blocked) {
            try s1.read()
        }

        try s1.close()
        try s2.close()
    }

    @Test
    func socketRead_ThrowsDisconnected_WhenSocketIsClosed() throws {
        let (s1, s2) = try Socket.makeNonBlockingPair()
        try s1.close()
        try s2.close()

        #expect(throws: SocketError.disconnected) {
            try s1.read()
        }
    }

    @Test
    func socketWrite_ThrowsBlocked_WhenBufferIsFull() throws {
        let (s1, s2) = try Socket.makeNonBlockingPair()
        try s1.setValue(1024, for: .sendBufferSize)
        let data = Data(repeating: 0x01, count: 8192)
        let sent = try s1.write(data, from: data.startIndex)

        #expect(throws: SocketError.blocked) {
            try s1.write(data, from: sent)
        }

        try s1.close()
        try s2.close()
    }

    @Test
    func socketWrite_Throws_WhenSocketIsNotConnected() async throws {
        let s1 = try Socket(domain: AF_UNIX, type: Socket.stream)
        let data = Data(repeating: 0x01, count: 100)
        #expect(throws: SocketError.self) {
            try s1.write(data, from: data.startIndex)
        }
        try s1.close()
    }

    @Test
    func socket_Sets_And_Gets_ReceiveBufferSize() throws {
        let socket = try Socket(domain: AF_UNIX, type: Socket.stream)

        try socket.setValue(2048, for: .receiveBufferSize)
#if canImport(Darwin)
        #expect(try socket.getValue(for: .receiveBufferSize) == Int32(2048))
#else
        // Linux kernel doubles this value (to allow space for bookkeeping overhead)
        #expect(try socket.getValue(for: .receiveBufferSize) >= Int32(4096))
#endif
    }

    @Test
    func socket_Sets_And_Gets_SendBufferSizeOption() throws {
        let socket = try Socket(domain: AF_UNIX, type: Socket.stream)

        try socket.setValue(2048, for: .sendBufferSize)
#if canImport(Darwin)
        #expect(try socket.getValue(for: .sendBufferSize) == Int32(2048))
#else
        // Linux kernel doubles this value (to allow space for bookkeeping overhead)
        #expect(try socket.getValue(for: .sendBufferSize) >= Int32(4096))
#endif
    }

    @Test
    func socket_Sets_And_Gets_BoolOption() throws {
        let socket = try Socket(domain: AF_UNIX, type: Socket.stream)

        try socket.setValue(true, for: .localAddressReuse)
        #expect(try socket.getValue(for: .localAddressReuse))

        try socket.setValue(false, for: .localAddressReuse)
        #expect(try socket.getValue(for: .localAddressReuse) == false)
    }

    @Test
    func socket_Sets_And_Gets_Flags() throws {
        let socket = try Socket(domain: AF_UNIX, type: Socket.stream)
        #expect(try socket.flags.contains(.append) == false)

        try socket.setFlags(.append)
        #expect(try socket.flags.contains(.append))
    }

    @Test
    func socketInit_ThrowsError_WhenInvalid() {
        #expect(throws: SocketError.self) {
            _ = try Socket(domain: -1, type: -1)
        }
    }

    @Test
    func socketAccept_ThrowsError_WhenInvalid() {
        let socket = Socket(file: -1)
        #expect(throws: SocketError.self) {
            try socket.accept()
        }
    }

    @Test
    func socketConnect_ThrowsError_WhenInvalid() {
        let socket = Socket(file: -1)
        #expect(throws: SocketError.self) {
            try socket.connect(to: .unix(path: "test"))
        }
    }

    @Test
    func socketClose_ThrowsError_WhenInvalid() {
        let socket = Socket(file: -1)
        #expect(throws: SocketError.self) {
            try socket.close()
        }
    }

    @Test
    func socketListen_ThrowsError_WhenInvalid() {
        let socket = Socket(file: -1)
        #expect(throws: SocketError.self) {
            try socket.listen()
        }
    }

    @Test
    func socketBind_ToINET() throws {
        let socket = try Socket(domain: AF_INET, type: Socket.stream)
        try socket.setValue(true, for: .localAddressReuse)
        let address = Socket.makeAddressINET(port:5050)
        #expect(throws: Never.self) {
            try socket.bind(to: address)
        }

        try? socket.close()
    }

    @Test
    func socketBind_ToINET6_ThrowsError_WhenInvalid() {
        let socket = Socket(file: -1)
        let address = Socket.makeAddressINET6(port: 8080)
        #expect(throws: SocketError.self) {
            try socket.bind(to: address)
        }
    }

    @Test
    func socketBind_ToStorage_ThrowsError_WhenInvalid() {
        let socket = Socket(file: -1)
        let address = Socket.makeAddressINET6(port: 8080)
        #expect(throws: SocketError.self) {
            try socket.bind(to: address)
        }
    }

    @Test
    func socketGetOption_ThrowsError_WhenInvalid() {
        let socket = Socket(file: -1)
        #expect(throws: SocketError.self) {
            _ = try socket.getValue(for: .localAddressReuse)
        }
    }

    @Test
    func socketSetOption_ThrowsError_WhenInvalid() {
        let socket = Socket(file: -1)
        #expect(throws: SocketError.self) {
            try socket.setValue(true, for: .localAddressReuse)
        }
    }

    @Test
    func socketGetFlags_ThrowsError_WhenInvalid() {
        let socket = Socket(file: -1)
        #expect(throws: SocketError.self) {
            _ = try socket.flags
        }
    }

    @Test
    func socketSetFlags_ThrowsError_WhenInvalid() {
        let socket = Socket(file: -1)
        #expect(throws: SocketError.self) {
            try socket.setFlags(.nonBlocking)
        }
    }

    @Test
    func socketRemotePeer_ThrowsError_WhenInvalid() {
        let socket = Socket(file: -1)
        #expect(throws: SocketError.self) {
            try socket.remotePeer()
        }
    }

    @Test
    func socket_sockname_ThrowsError_WhenInvalid() {
        let socket = Socket(file: -1)
        #expect(throws: SocketError.self) {
            try socket.sockname()
        }
    }

    @Test
    func ntop_ThrowsError_WhenBufferIsTooSmall() {
        var addr = Socket.makeAddressINET6(port: 8080)
        let maxLength = socklen_t(1)
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(maxLength))
        #expect(throws: SocketError.self) {
            try Socket.inet_ntop(AF_INET6, &addr.sin6_addr, buffer, maxLength)
        }
    }
}

extension Socket.Flags {
    static let append = Socket.Flags(rawValue: O_APPEND)
}

private extension Socket {
    init(file: Int32) {
        self.init(file: .init(rawValue: file))
    }
}
