//
//  Socket.swift
//  FlyingFox
//
//  Created by Simon Whitty on 13/02/2022.
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

#if canImport(WinSDK)
import WinSDK.WinSock2
#elseif canImport(Android)
@_exported import Android
#endif
import Foundation

public enum SocketType: Sendable {
    case stream
    case datagram
}

package extension SocketType {
    var rawValue: Int32 {
        switch self {
        case .stream:
            Socket.stream
        case .datagram:
            Socket.datagram
        }
    }

    init(rawValue: Int32) throws {
        switch rawValue {
        case Socket.stream:
            self = .stream
        case Socket.datagram:
            self = .datagram
        default:
            throw SocketError.makeFailed("Invalid SocketType")
        }
    }
}

public struct Socket: Sendable, Hashable {

    public let file: FileDescriptor

    public struct FileDescriptor: RawRepresentable, Sendable, Hashable {
        public var rawValue: Socket.FileDescriptorType

        public init(rawValue: Socket.FileDescriptorType) {
            self.rawValue = rawValue
        }
    }

    public init(file: FileDescriptor) {
        self.file = file
    }

    public init(domain: Int32) throws {
        try self.init(domain: domain, type: .stream)
    }

    @available(*, deprecated, message: "type is now SocketType")
    public init(domain: Int32, type: Int32) throws {
        try self.init(domain: domain, type: SocketType(rawValue: type))
    }

    public init(domain: Int32, type: SocketType) throws {
        let descriptor = FileDescriptor(rawValue: Socket.socket(domain, type.rawValue, 0))
        guard descriptor != .invalid else {
            throw SocketError.makeFailed("CreateSocket")
        }
        self.file = descriptor
        if type == .datagram {
            try setPktInfo(domain: domain)
        }
    }

    public var socketType: SocketType {
        get throws {
            try SocketType(rawValue: getValue(for: .socketType))
        }
    }

    public var flags: Flags {
        get throws {
            let flags = Socket.fcntl(file.rawValue, F_GETFL)
            if flags == -1 {
                throw SocketError.makeFailed("GetFlags")
            }
            return Flags(rawValue: flags)
        }
    }

    public func setFlags(_ flags: Flags) throws {
        if Socket.fcntl(file.rawValue, F_SETFL, flags.rawValue) == -1 {
            throw SocketError.makeFailed("SetFlags")
        }
    }

    // enable return of ip_pktinfo/ipv6_pktinfo on recvmsg()
    private func setPktInfo(domain: Int32) throws {
        switch domain {
        case AF_INET:
            try setValue(true, for: .packetInfoIP)
        case AF_INET6:
            try setValue(true, for: .packetInfoIPv6)
        default:
            return
        }
    }

    public func setValue<O: SocketOption>(_ value: O.Value, for option: O) throws {
        var value = option.makeSocketValue(from: value)
        let result = withUnsafeBytes(of: &value) {
            Socket.setsockopt(file.rawValue, option.level, option.name, $0.baseAddress!, socklen_t($0.count))
        }
        guard result >= 0 else {
            throw SocketError.makeFailed("SetOption")
        }
    }

    public func getValue<O: SocketOption>(for option: O) throws -> O.Value {
        let valuePtr = UnsafeMutablePointer<O.SocketValue>.allocate(capacity: 1)
        var length = socklen_t(MemoryLayout<O.SocketValue>.size)
        guard Socket.getsockopt(file.rawValue, option.level, option.name, valuePtr, &length) >= 0 else {
            throw SocketError.makeFailed("GetOption")
        }
        return option.makeValue(from: valuePtr.pointee)
    }

    public func bind(to address: some SocketAddress) throws {
        let result = address.withSockAddr {
            Socket.bind(file.rawValue, $0, address.size)
        }
        guard result >= 0 else {
            throw SocketError.makeFailed("Bind")
        }
    }

    public func listen(maxPendingConnection: Int32 = SOMAXCONN) throws {
        if Socket.listen(file.rawValue, maxPendingConnection) == -1 {
            let error = SocketError.makeFailed("Listen")
            try close()
            throw error
        }
    }

    public func remotePeer() throws -> Address {
        var addr = sockaddr_storage()
        var len = socklen_t(MemoryLayout<sockaddr_storage>.size)

        let result = addr.withMutableSockAddr {
            Socket.getpeername(file.rawValue, $0, &len)
        }
        if result != 0 {
            throw SocketError.makeFailed("GetPeerName")
        }
        return try Self.makeAddress(from: addr)
    }

    public func sockname() throws -> Address {
        var addr = sockaddr_storage()
        var len = socklen_t(MemoryLayout<sockaddr_storage>.size)

        let result = addr.withMutableSockAddr {
            Socket.getsockname(file.rawValue, $0, &len)
        }
        if result != 0 {
            throw SocketError.makeFailed("GetSockName")
        }
        return try Self.makeAddress(from: addr)
    }

    public func accept() throws -> (file: FileDescriptor, addr: sockaddr_storage) {
        var addr = sockaddr_storage()
        var len = socklen_t(MemoryLayout<sockaddr_storage>.size)

        let newFile = addr.withMutableSockAddr {
            FileDescriptor(rawValue: Socket.accept(file.rawValue, $0, &len))
        }

        guard newFile != .invalid else {
            if errno == EWOULDBLOCK {
                throw SocketError.blocked
            } else {
                throw SocketError.makeFailed("Accept")
            }
        }

        return (newFile, addr)
    }

    public func connect(to address: some SocketAddress) throws {
        let result = address.withSockAddr {
            Socket.connect(file.rawValue, $0, address.size)
        }
        guard result >= 0 || errno == EISCONN else {
            if errno == EINPROGRESS {
                throw SocketError.blocked
            } else {
                throw SocketError.makeFailed("Connect")
            }
        }
    }

    public func read() throws -> UInt8 {
        var byte: UInt8 = 0
        _ = try withUnsafeMutablePointer(to: &byte) { buffer in
            try read(into: buffer, length: 1)
        }
        return byte
    }

    public func read(atMost length: Int) throws -> [UInt8] {
        try [UInt8](unsafeUninitializedCapacity: length) { buffer, count in
            count = try read(into: buffer.baseAddress!, length: length)
        }
    }

    private func read(into buffer: UnsafeMutablePointer<UInt8>, length: Int) throws -> Int {
        let count = Socket.read(file.rawValue, buffer, length)
        guard count > 0 else {
            if errno == EWOULDBLOCK {
                throw SocketError.blocked
            } else if errno == EBADF || count == 0 {
                throw SocketError.disconnected
            } else {
                throw SocketError.makeFailed("Read")
            }
        }
        return count
    }

    public func receive(length: Int) throws -> (any SocketAddress, [UInt8]) {
        var address: (any SocketAddress)?
        let bytes = try [UInt8](unsafeUninitializedCapacity: length) { buffer, count in
            (address, count) = try receive(into: buffer.baseAddress!, length: length)
        }

        return (address!, bytes)
    }

    private func receive(into buffer: UnsafeMutablePointer<UInt8>, length: Int) throws -> (any SocketAddress, Int) {
        var addr = sockaddr_storage()
        var size = socklen_t(MemoryLayout<sockaddr_storage>.size)
        let count = addr.withMutableSockAddr {
            Socket.recvfrom(file.rawValue, buffer, length, 0, $0, &size)
        }
        guard count > 0 else {
            if errno == EWOULDBLOCK {
                throw SocketError.blocked
            } else if errno == EBADF || count == 0 {
                throw SocketError.disconnected
            } else {
                throw SocketError.makeFailed("RecvFrom")
            }
        }
        return (addr, count)
    }

#if !canImport(WinSDK)
    public func receive(length: Int) throws -> (any SocketAddress, [UInt8], UInt32?, (any SocketAddress)?) {
        var peerAddress: (any SocketAddress)?
        var interfaceIndex: UInt32?
        var localAddress: (any SocketAddress)?

        let bytes = try [UInt8](unsafeUninitializedCapacity: length) { buffer, count in
            (peerAddress, count, interfaceIndex, localAddress) = try receive(into: buffer.baseAddress!, length: length, flags: 0)
        }

        return (peerAddress!, bytes, interfaceIndex, localAddress)
    }

    private static let ControlMsgBufferSize = MemoryLayout<cmsghdr>.size + max(MemoryLayout<in_pktinfo>.size, MemoryLayout<in6_pktinfo>.size)

    private func receive(
        into buffer: UnsafeMutablePointer<UInt8>,
        length: Int,
        flags: Int32
    ) throws -> (any SocketAddress, Int, UInt32?, (any SocketAddress)?) {
        var iov = iovec()
        var msg = msghdr()
        var peerAddress = sockaddr_storage()
        var localAddress: sockaddr_storage?
        var interfaceIndex: UInt32?
        var controlMsgBuffer = [UInt8](repeating: 0, count: Socket.ControlMsgBufferSize)

        iov.iov_base = UnsafeMutableRawPointer(buffer)
        iov.iov_len = IovLengthType(length)

        let count = withUnsafeMutablePointer(to: &iov) { iov in
            msg.msg_iov = iov
            msg.msg_iovlen = 1
            msg.msg_namelen = socklen_t(MemoryLayout<sockaddr_storage>.size)

            return withUnsafeMutablePointer(to: &peerAddress) { peerAddress in
                msg.msg_name = UnsafeMutableRawPointer(peerAddress)

                return controlMsgBuffer.withUnsafeMutableBytes { controlMsgBuffer in
                    msg.msg_control = UnsafeMutableRawPointer(controlMsgBuffer.baseAddress)
                    msg.msg_controllen = ControlMessageHeaderLengthType(controlMsgBuffer.count)

                    let count = Socket.recvmsg(file.rawValue, &msg, flags)

                    if count > 0, msg.msg_controllen != 0 {
                        (interfaceIndex, localAddress) = Socket.getPacketInfoControl(msghdr: msg)
                    }

                    return count
                }
            }
        }

        guard count > 0 else {
            if errno == EWOULDBLOCK || errno == EAGAIN {
                throw SocketError.blocked
            } else if errno == EBADF || count == 0 {
                throw SocketError.disconnected
            } else {
                throw SocketError.makeFailed("RecvMsg")
            }
        }

        return (peerAddress, count, interfaceIndex, localAddress)
    }
#endif

    public func write(_ data: Data, from index: Data.Index = 0) throws -> Data.Index {
        precondition(index >= 0)
        guard index < data.endIndex else { return data.endIndex }
        return try data.withUnsafeBytes { buffer in
            let sent = try write(buffer.baseAddress! + index - data.startIndex, length: data.endIndex - index)
            return index + sent
        }
    }

    private func write(_ pointer: UnsafeRawPointer, length: Int) throws -> Int {
        let sent = Socket.write(file.rawValue, pointer, length)
        guard sent > 0 else {
            if errno == EWOULDBLOCK {
                throw SocketError.blocked
            } else if errno == EBADF {
                throw SocketError.disconnected
            } else {
                throw SocketError.makeFailed("Write")
            }
        }
        return sent
    }

    public func send(_ bytes: [UInt8], to address: some SocketAddress) throws -> Int {
        try bytes.withUnsafeBytes { buffer in
            try send(buffer.baseAddress!, length: bytes.count, to: address)
        }
    }

    private func send(_ pointer: UnsafeRawPointer, length: Int, to address: some SocketAddress) throws -> Int {
        let sent = address.withSockAddr {
            Socket.sendto(file.rawValue, pointer, length, 0, $0, address.size)
        }
        guard sent >= 0 else {
            if errno == EWOULDBLOCK || errno == EAGAIN {
                throw SocketError.blocked
            } else {
                throw SocketError.makeFailed("SendTo")
            }
        }
        return sent
    }

#if !canImport(WinSDK)
    public func send(
        message: [UInt8],
        to peerAddress: some SocketAddress,
        interfaceIndex: UInt32? = nil,
        from localAddress: (some SocketAddress)? = nil
    ) throws -> Int {
        try message.withUnsafeBytes { buffer in
            try send(
                buffer.baseAddress!,
                length: buffer.count,
                flags: 0,
                to: peerAddress,
                interfaceIndex: interfaceIndex,
                from: localAddress
            )
        }
    }

    private func send(
        _ pointer: UnsafeRawPointer,
        length: Int,
        flags: Int32,
        to peerAddress: some SocketAddress,
        interfaceIndex: UInt32? = nil,
        from localAddress: (some SocketAddress)? = nil
    ) throws -> Int {
        var iov = iovec()
        var msg = msghdr()
        let family = peerAddress.family

        iov.iov_base = UnsafeMutableRawPointer(mutating: pointer)
        iov.iov_len = IovLengthType(length)

        let sent = withUnsafeMutablePointer(to: &iov) { iov in
            var peerAddress = peerAddress

            msg.msg_iov = iov
            msg.msg_iovlen = 1
            msg.msg_namelen = peerAddress.size

            return withUnsafeMutablePointer(to: &peerAddress) { peerAddress in
                msg.msg_name = UnsafeMutableRawPointer(peerAddress)

                return Socket.withPacketInfoControl(
                    family: family,
                    interfaceIndex: interfaceIndex,
                    address: localAddress) { control, controllen in
                    if let control {
                        msg.msg_control = UnsafeMutableRawPointer(mutating: control)
                        msg.msg_controllen = controllen
                    }
                    return Socket.sendmsg(file.rawValue, &msg, flags)
                }
            }
        }

        guard sent >= 0 else {
            if errno == EWOULDBLOCK || errno == EAGAIN {
                throw SocketError.blocked
            } else {
                throw SocketError.makeFailed("SendMsg")
            }
        }

        return sent
    }
#endif

    public func close() throws {
        if Socket.close(file.rawValue) == -1 {
            throw SocketError.makeFailed("Close")
        }
    }
}

public extension Socket {
    struct Flags: OptionSet, Sendable {
        public var rawValue: Int32

        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        public static let nonBlocking = Flags(rawValue: O_NONBLOCK)
    }
}

public extension Socket {

    enum Event: Sendable {
        case read
        case write
    }

    typealias Events = Set<Event>
}

extension Socket.Event: CustomStringConvertible {
    public var description: String {
        switch self {
        case .read:
            return "read"
        case .write:
            return "write"
        }
    }
}

public extension Socket.Events {
    static let read: Self = [.read]
    static let write: Self = [.write]
    static let connection: Self = [.read, .write]
}

public protocol SocketOption {
    associatedtype Value
    associatedtype SocketValue

    var level: Int32 { get }
    var name: Int32 { get }
    func makeValue(from socketValue: SocketValue) -> Value
    func makeSocketValue(from value: Value) -> SocketValue
}

public extension SocketOption {
    var level: Int32 { SOL_SOCKET }
}

public struct BoolSocketOption: SocketOption {
    public var level: Int32
    public var name: Int32

    public init(level: Int32 = SOL_SOCKET, name: Int32) {
        self.level = level
        self.name = name
    }

    public func makeValue(from socketValue: Int32) -> Bool {
        socketValue > 0
    }

    public func makeSocketValue(from value: Bool) -> Int32 {
        value ? 1 : 0
    }
}

public struct Int32SocketOption: SocketOption {
    public var level: Int32
    public var name: Int32

    public init(level: Int32 = SOL_SOCKET, name: Int32) {
        self.level = level
        self.name = name
    }

    public func makeValue(from socketValue: Int32) -> Int32 {
        socketValue
    }

    public func makeSocketValue(from value: Int32) -> Int32 {
        value
    }
}

public extension SocketOption where Self == BoolSocketOption {
    static var localAddressReuse: Self {
        BoolSocketOption(name: SO_REUSEADDR)
    }

    static var packetInfoIP: Self {
        BoolSocketOption(level: Socket.ipproto_ip, name: Socket.ip_pktinfo)
    }

    static var packetInfoIPv6: Self {
        BoolSocketOption(level: Socket.ipproto_ipv6, name: Socket.ipv6_recvpktinfo)
    }

    #if canImport(Darwin)
    // Prevents SIG_TRAP when app is paused / running in background.
    static var noSIGPIPE: Self {
        BoolSocketOption(name: SO_NOSIGPIPE)
    }
    #endif
}

public extension SocketOption where Self == Int32SocketOption {

    static var socketType: Self {
        Int32SocketOption(name: SO_TYPE)
    }

    static var sendBufferSize: Self {
        Int32SocketOption(name: SO_SNDBUF)
    }

    static var receiveBufferSize: Self {
        Int32SocketOption(name: SO_RCVBUF)
    }
}

package extension Socket {

    static func makePair(flags: Flags? = nil, type: SocketType = .stream) throws -> (Socket, Socket) {
        let (file1, file2) = Socket.socketpair(AF_UNIX, type.rawValue, 0)
        guard file1 > -1, file2 > -1 else {
            throw SocketError.makeFailed("SocketPair")
        }
        let s1 = Socket(file: .init(rawValue: file1))
        let s2 = Socket(file: .init(rawValue: file2))

        if let flags {
            try s1.setFlags(flags)
            try s2.setFlags(flags)
        }
        return (s1, s2)
    }

    static func makeNonBlockingPair(type: SocketType = .stream) throws -> (Socket, Socket) {
        try Socket.makePair(flags: .nonBlocking, type: type)
    }
}

#if !canImport(WinSDK)
fileprivate extension Socket {
    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0138-unsaferawbufferpointer.md
    private static func withControlMessage(
        control: UnsafeRawPointer,
        controllen: ControlMessageHeaderLengthType,
        _ body: (cmsghdr, UnsafeRawBufferPointer) -> ()
    ) {
        let controlBuffer = UnsafeRawBufferPointer(start: control, count: Int(controllen))
        var cmsgHeaderIndex = 0

        while true {
            let cmsgDataIndex = cmsgHeaderIndex + MemoryLayout<cmsghdr>.stride

            if cmsgDataIndex > controllen {
                break
            }

            let header = controlBuffer.load(fromByteOffset: cmsgHeaderIndex, as: cmsghdr.self)
            if Int(header.cmsg_len) < MemoryLayout<cmsghdr>.stride {
                break
            }

            cmsgHeaderIndex = cmsgDataIndex
            cmsgHeaderIndex += Int(header.cmsg_len) - MemoryLayout<cmsghdr>.stride
            if cmsgHeaderIndex > controlBuffer.count {
                break
            }
            body(header, UnsafeRawBufferPointer(rebasing: controlBuffer[cmsgDataIndex..<cmsgHeaderIndex]))

            cmsgHeaderIndex += MemoryLayout<cmsghdr>.alignment - 1
            cmsgHeaderIndex &= ~(MemoryLayout<cmsghdr>.alignment - 1)
        }
    }

    static func getPacketInfoControl(
        msghdr: msghdr
    ) -> (UInt32?, sockaddr_storage?) {
        var interfaceIndex: UInt32?
        var localAddress = sockaddr_storage()

        withControlMessage(control: msghdr.msg_control, controllen: msghdr.msg_controllen) { cmsghdr, cmsgdata in
            switch cmsghdr.cmsg_level {
            case Socket.ipproto_ip:
                guard cmsghdr.cmsg_type == Socket.ip_pktinfo else { break }
                cmsgdata.baseAddress!.withMemoryRebound(to: in_pktinfo.self, capacity: 1) { pktinfo in
                    var sin = sockaddr_in()
                    sin.sin_addr = pktinfo.pointee.ipi_addr
                    interfaceIndex = UInt32(pktinfo.pointee.ipi_ifindex)
                    localAddress = sin.makeStorage()
                }
            case Socket.ipproto_ipv6:
                guard cmsghdr.cmsg_type == Socket.ipv6_pktinfo else { break }
                cmsgdata.baseAddress!.withMemoryRebound(to: in6_pktinfo.self, capacity: 1) { pktinfo in
                    var sin6 = sockaddr_in6()
                    sin6.sin6_addr = pktinfo.pointee.ipi6_addr
                    interfaceIndex = UInt32(pktinfo.pointee.ipi6_ifindex)
                    localAddress = sin6.makeStorage()
                }
            default:
                break
            }
        }

        return (interfaceIndex, interfaceIndex != nil ? localAddress : nil)
    }

    static func withPacketInfoControl<T>(
        family: sa_family_t,
        interfaceIndex: UInt32?,
        address: (some SocketAddress)?,
        _ body: (UnsafePointer<cmsghdr>?, ControlMessageHeaderLengthType) -> T
    ) -> T {
        switch Int32(family) {
        case AF_INET:
            let buffer = ManagedBuffer<cmsghdr, in_pktinfo>.create(minimumCapacity: 1) { buffer in
                buffer.withUnsafeMutablePointers { header, element in
                    header.pointee.cmsg_len = ControlMessageHeaderLengthType(MemoryLayout<cmsghdr>.size + MemoryLayout<in_pktinfo>.size)
                    header.pointee.cmsg_level = SOL_SOCKET
                    header.pointee.cmsg_type = Socket.ipproto_ip
                    element.pointee.ipi_ifindex = IPv4InterfaceIndexType(interfaceIndex ?? 0)
                    if let address {
                        var address = address
                        withUnsafePointer(to: &address) {
                            $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                                element.pointee.ipi_addr = $0.pointee.sin_addr
                            }
                        }
                    } else {
                        element.pointee.ipi_addr.s_addr = 0
                    }

                    return header.pointee
                }
            }

            return buffer.withUnsafeMutablePointerToHeader { body($0, ControlMessageHeaderLengthType($0.pointee.cmsg_len)) }
        case AF_INET6:
            let buffer = ManagedBuffer<cmsghdr, in6_pktinfo>.create(minimumCapacity: 1) { buffer in
                buffer.withUnsafeMutablePointers { header, element in
                    header.pointee.cmsg_len = ControlMessageHeaderLengthType(MemoryLayout<cmsghdr>.size + MemoryLayout<in6_pktinfo>.size)
                    header.pointee.cmsg_level = SOL_SOCKET
                    header.pointee.cmsg_type = Socket.ipproto_ipv6
                    element.pointee.ipi6_ifindex = IPv6InterfaceIndexType(interfaceIndex ?? 0)
                    if let address {
                        var address = address
                        withUnsafePointer(to: &address) {
                            $0.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                                element.pointee.ipi6_addr = $0.pointee.sin6_addr
                            }
                        }
                    } else {
                        element.pointee.ipi6_addr = in6_addr()
                    }

                    return header.pointee
                }
            }

            return buffer.withUnsafeMutablePointerToHeader { body($0, ControlMessageHeaderLengthType($0.pointee.cmsg_len)) }
        default:
            return body(nil, 0)
        }
    }
}
#endif
