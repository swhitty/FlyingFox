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
    func socketType_init() throws {
        #expect(try SocketType(rawValue: Socket.stream) == .stream)
        #expect(try SocketType(rawValue: Socket.datagram) == .datagram)
        #expect(throws: (any Error).self) {
            try SocketType(rawValue: -1)
        }
    }

    @Test
    func socketType_rawValue() {
        #expect(SocketType.stream.rawValue == Socket.stream)
        #expect(SocketType.datagram.rawValue == Socket.datagram)
    }

    @Test
    func getSocketType_stream() throws {
        #expect(
            try Socket(domain: AF_INET).socketType == .stream
        )
        #expect(
            try Socket(domain: AF_INET6).socketType == .stream
        )
        #expect(
            try Socket(domain: AF_UNIX).socketType == .stream
        )
        #expect(
            try Socket(domain: AF_INET, type: .stream).socketType == .stream
        )
        #expect(
            try Socket(domain: AF_INET, type: .stream).socketType == .stream
        )
        #expect(
            try Socket(domain: AF_INET, type: .stream).socketType == .stream
        )
    }

    @Test
    func getSocketType_datagram() throws {
        #expect(
            try Socket(domain: AF_INET, type: .datagram).socketType == .datagram
        )
        #expect(
            try Socket(domain: AF_INET, type: .datagram).socketType == .datagram
        )
        #expect(
            try Socket(domain: AF_INET, type: .datagram).socketType == .datagram
        )
    }

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

        #expect(throws: (any Error).self) {
            try s1.read()
        }
    }

    #if !canImport(WinSDK)
    // Not a good test on Windows, unfortunately:
    // https://groups.google.com/g/microsoft.public.win32.programmer.networks/c/rBg0a8oERGQ/m/AvVOd-BIHhMJ
    // "If necessary, Winsock can buffer significantly more than the SO_SNDBUF buffer size."

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
    #endif

    @Test
    func socketWrite_Throws_WhenSocketIsNotConnected() async throws {
        let s1 = try Socket(domain: AF_UNIX, type: .stream)
        let data = Data(repeating: 0x01, count: 100)
        #expect(throws: SocketError.self) {
            try s1.write(data, from: data.startIndex)
        }
        try s1.close()
    }

    @Test
    func socket_Sets_And_Gets_ReceiveBufferSize() throws {
        let socket = try Socket(domain: AF_UNIX, type: .stream)

        try socket.setValue(2048, for: .receiveBufferSize)
#if canImport(Darwin) || canImport(WinSDK)
        #expect(try socket.getValue(for: .receiveBufferSize) == Int32(2048))
#else
        // Linux kernel doubles this value (to allow space for bookkeeping overhead)
        #expect(try socket.getValue(for: .receiveBufferSize) >= Int32(4096))
#endif
    }

    @Test
    func socket_Sets_And_Gets_SendBufferSizeOption() throws {
        let socket = try Socket(domain: AF_UNIX, type: .stream)

        try socket.setValue(2048, for: .sendBufferSize)
#if canImport(Darwin) || canImport(WinSDK)
        #expect(try socket.getValue(for: .sendBufferSize) == Int32(2048))
#else
        // Linux kernel doubles this value (to allow space for bookkeeping overhead)
        #expect(try socket.getValue(for: .sendBufferSize) >= Int32(4096))
#endif
    }

    @Test
    func socket_Sets_And_Gets_BoolOption() throws {
        let socket = try Socket(domain: AF_UNIX, type: .stream)

        try socket.setValue(true, for: .localAddressReuse)
        #expect(try socket.getValue(for: .localAddressReuse))

        try socket.setValue(false, for: .localAddressReuse)
        #expect(try socket.getValue(for: .localAddressReuse) == false)
    }

    #if canImport(WinSDK)
    @Test
    func windows_wsa_startup_succeeds() {
        let status = WSALifecycle.startup()
        #expect(status.isStarted)
        #expect(status.acceptedVersion == WSALifecycle.minimumRequiredVersion)
        #expect(status == WSALifecycle.status)
    }

    // Windows only supports setting O_NONBLOCK, and currently can't retrieve whether it's been set :)
    @Test
    func socket_Throws_On_Get_Flags() throws {
        let socket = try Socket(domain: AF_UNIX, type: .stream)

        try socket.setFlags(.append) // this is "OK", but actually won't set the flag
        #expect(throws: SocketError.self) { try socket.flags.contains(.append) }
    }
    #else
    @Test
    func socket_Sets_And_Gets_Flags() throws {
        let socket = try Socket(domain: AF_UNIX, type: .stream)
        #expect(try socket.flags.contains(.append) == false)

        try socket.setFlags(.append)
        #expect(try socket.flags.contains(.append))
    }
    #endif

    @Test
    func socketAccept_ThrowsError_WhenInvalid() {
        let socket = Socket.invalid()
        #expect(throws: SocketError.self) {
            try socket.accept()
        }
    }

    @Test
    func socketConnect_ThrowsError_WhenInvalid() {
        let socket = Socket.invalid()
        #expect(throws: SocketError.self) {
            try socket.connect(to: .unix(path: "test"))
        }
    }

    @Test
    func socketClose_ThrowsError_WhenInvalid() {
        let socket = Socket.invalid()
        #expect(throws: SocketError.self) {
            try socket.close()
        }
    }

    @Test
    func socketListen_ThrowsError_WhenInvalid() {
        let socket = Socket.invalid()
        #expect(throws: SocketError.self) {
            try socket.listen()
        }
    }

    @Test
    func socketBind_ToINET() throws {
        let socket = try Socket(domain: AF_INET, type: .stream)
        try socket.setValue(true, for: .localAddressReuse)
        let address = Socket.makeAddressINET(port:5050)
        #expect(throws: Never.self) {
            try socket.bind(to: address)
        }

        try? socket.close()
    }

    @Test
    func socketBind_ToINET6_ThrowsError_WhenInvalid() {
        let socket = Socket.invalid()
        let address = Socket.makeAddressINET6(port: 8080)
        #expect(throws: SocketError.self) {
            try socket.bind(to: address)
        }
    }

    @Test
    func socketBind_ToStorage_ThrowsError_WhenInvalid() {
        let socket = Socket.invalid()
        let address = Socket.makeAddressINET6(port: 8080)
        #expect(throws: SocketError.self) {
            try socket.bind(to: address)
        }
    }

    @Test
    func socketGetOption_ThrowsError_WhenInvalid() {
        let socket = Socket.invalid()
        #expect(throws: SocketError.self) {
            _ = try socket.getValue(for: .localAddressReuse)
        }
    }

    @Test
    func socketSetOption_ThrowsError_WhenInvalid() {
        let socket = Socket.invalid()
        #expect(throws: SocketError.self) {
            try socket.setValue(true, for: .localAddressReuse)
        }
    }

    @Test
    func socketGetFlags_ThrowsError_WhenInvalid() {
        let socket = Socket.invalid()
        #expect(throws: SocketError.self) {
            _ = try socket.flags
        }
    }

    @Test
    func socketSetFlags_ThrowsError_WhenInvalid() {
        let socket = Socket.invalid()
        #expect(throws: SocketError.self) {
            try socket.setFlags(.nonBlocking)
        }
    }

    @Test
    func socketRemotePeer_ThrowsError_WhenInvalid() {
        let socket = Socket.invalid()
        #expect(throws: SocketError.self) {
            try socket.remotePeer()
        }
    }

    @Test
    func socket_sockname_ThrowsError_WhenInvalid() {
        let socket = Socket.invalid()
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

    @Test
    func makes_datagram_ip4() throws {
        let socket = try Socket(domain: Int32(sa_family_t(AF_INET)), type: .datagram)

        #expect(
            try socket.getValue(for: .packetInfoIP) == true
        )
    }

    @Test
    func makes_datagram_ip6() throws {
        let socket = try Socket(domain: Int32(sa_family_t(AF_INET6)), type: .datagram)

        #expect(
            try socket.getValue(for: .packetInfoIPv6) == true
        )
    }
}

extension Socket.Flags {
    static let append = Socket.Flags(rawValue: O_APPEND)
}

private extension Socket {
    init(file: FileDescriptorType) {
        self.init(file: .init(rawValue: file))
    }

    static func invalid() -> Socket {
        #if canImport(WinSDK)
        self.init(file: .init(rawValue: INVALID_SOCKET))
        #else
        self.init(file: .init(rawValue: -1))
        #endif
    }
}
