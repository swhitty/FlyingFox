//
//  Socket+Android.swift
//  FlyingFox
//
//  Created by Simon Whitty on 26/09/2024.
//  Copyright © 2024 Simon Whitty. All rights reserved.
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

#if canImport(Android)
import Android

// from linux/eventpoll.h, not imported by clang importer
let EPOLLET: UInt32 = 1 << 31;

public extension Socket {
    typealias FileDescriptorType = Int32
    typealias IovLengthType = UInt
    typealias ControlMessageHeaderLengthType = Int
    typealias IPv4InterfaceIndexType = Int32
    typealias IPv6InterfaceIndexType = Int32
}

extension Socket.FileDescriptor {
    static let invalid = Socket.FileDescriptor(rawValue: -1)
}

extension Socket {
    static let stream = Int32(SOCK_STREAM)
    static let datagram = Int32(SOCK_DGRAM)
    static let in_addr_any = Android.in_addr(s_addr: Android.in_addr_t(0))
    static let ipproto_ip = Int32(IPPROTO_IP)
    static let ipproto_ipv6 = Int32(IPPROTO_IPV6)
    static let ip_pktinfo = Int32(IP_PKTINFO)
    static let ipv6_pktinfo = Int32(IPV6_PKTINFO)
    static let ipv6_recvpktinfo = Int32(IPV6_RECVPKTINFO)

    static func makeAddressINET(port: UInt16) -> Android.sockaddr_in {
        Android.sockaddr_in(
            sin_family: sa_family_t(AF_INET),
            sin_port: port.bigEndian,
            sin_addr: in_addr_any,
            __pad: (0, 0, 0, 0, 0, 0, 0, 0)
        )
    }

    static func makeAddressINET6(port: UInt16) -> Android.sockaddr_in6 {
        Android.sockaddr_in6(
            sin6_family: sa_family_t(AF_INET6),
            sin6_port: port.bigEndian,
            sin6_flowinfo: 0,
            sin6_addr: in6addr_any,
            sin6_scope_id: 0
        )
    }

    static func makeAddressLoopback(port: UInt16) -> Android.sockaddr_in6 {
        Android.sockaddr_in6(
            sin6_family: sa_family_t(AF_INET6),
            sin6_port: port.bigEndian,
            sin6_flowinfo: 0,
            sin6_addr: in6addr_loopback,
            sin6_scope_id: 0
        )
    }

    static func makeAddressUnix(path: String) -> Android.sockaddr_un {
        var addr = Android.sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathCount = min(path.utf8.count, 104)
        let len = UInt8(MemoryLayout<UInt8>.size + MemoryLayout<sa_family_t>.size + pathCount + 1)
        _ = withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            path.withCString {
                strncpy(ptr, $0, Int(len))
            }
        }
        return addr
    }

    static func makeAbstractNamespaceUnix(name: String) -> WinSDK.sockaddr_un {
        var addr: sockaddr_un = Android.sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        _ = withUnsafeMutableBytes(of: &addr.sun_path) { raw in
            raw.initializeMemory(as: CChar.self, repeating: 0)
        }

        let nameBytes = Array(name.utf8.prefix(107))
        nameBytes.withUnsafeBytes { src in
            withUnsafeMutableBytes(of: &addr.sun_path) { dst in
                dst[1 ..< 1 + src.count].copyBytes(from: src)
            }
        }

        return addr
    }

    static func socket(_ domain: Int32, _ type: Int32, _ protocol: Int32) -> FileDescriptorType {
        Android.socket(domain, type, `protocol`)
    }

    static func socketpair(_ domain: Int32, _ type: Int32, _ protocol: Int32) -> (FileDescriptorType, FileDescriptorType) {
        var sockets: [Int32] = [-1, -1]
        _ = Android.socketpair(domain, type, `protocol`, &sockets)
        return (sockets[0], sockets[1])
    }

    static func fcntl(_ fd: Int32, _ cmd: Int32) -> Int32 {
        Android.fcntl(fd, cmd)
    }

    static func fcntl(_ fd: Int32, _ cmd: Int32, _ value: Int32) -> Int32 {
        Android.fcntl(fd, cmd, value)
    }

    static func setsockopt(_ fd: Int32, _ level: Int32, _ name: Int32,
                           _ value: UnsafeRawPointer!, _ len: socklen_t) -> Int32 {
        Android.setsockopt(fd, level, name, value, len)
    }

    static func getsockopt(_ fd: Int32, _ level: Int32, _ name: Int32,
                           _ value: UnsafeMutableRawPointer!, _ len: UnsafeMutablePointer<socklen_t>!) -> Int32 {
        Android.getsockopt(fd, level, name, value, len)
    }

    static func getpeername(_ fd: Int32, _ addr: UnsafeMutablePointer<sockaddr>!, _ len: UnsafeMutablePointer<socklen_t>!) -> Int32 {
        Android.getpeername(fd, addr, len)
    }

    static func getsockname(_ fd: Int32, _ addr: UnsafeMutablePointer<sockaddr>!, _ len: UnsafeMutablePointer<socklen_t>!) -> Int32 {
        Android.getsockname(fd, addr, len)
    }

    static func inet_ntop(_ domain: Int32, _ addr: UnsafeRawPointer!,
                          _ buffer: UnsafeMutablePointer<CChar>!, _ addrLen: socklen_t) throws {
        if Android.inet_ntop(domain, addr, buffer, addrLen) == nil {
            throw SocketError.makeFailed("inet_ntop")
        }
    }

    static func inet_pton(_ domain: Int32, _ buffer: UnsafePointer<CChar>!, _ addr: UnsafeMutableRawPointer!) -> Int32 {
        Android.inet_pton(domain, buffer, addr)
    }

    static func bind(_ fd: Int32, _ addr: UnsafePointer<sockaddr>!, _ len: socklen_t) -> Int32 {
        Android.bind(fd, addr, len)
    }

    static func listen(_ fd: Int32, _ backlog: Int32) -> Int32 {
        Android.listen(fd, backlog)
    }

    static func accept(_ fd: Int32, _ addr: UnsafeMutablePointer<sockaddr>!, _ len: UnsafeMutablePointer<socklen_t>!) -> Int32 {
        Android.accept(fd, addr, len)
    }

    static func connect(_ fd: Int32, _ addr: UnsafePointer<sockaddr>!, _ len: socklen_t) -> Int32 {
        Android.connect(fd, addr, len)
    }

    static func read(_ fd: Int32, _ buffer: UnsafeMutableRawPointer!, _ nbyte: Int) -> Int {
        Android.read(fd, buffer, nbyte)
    }

    static func write(_ fd: Int32, _ buffer: UnsafeRawPointer!, _ nbyte: Int) -> Int {
        Android.send(fd, buffer, nbyte, Int32(MSG_NOSIGNAL))
    }

    static func close(_ fd: Int32) -> Int32 {
        Android.close(fd)
    }

    static func unlink(_ addr: UnsafePointer<CChar>!) -> Int32 {
        Android.unlink(addr)
    }

    static func poll(_ fds: UnsafeMutablePointer<pollfd>!, _ nfds: UInt32, _ tmo_p: Int32) -> Int32 {
        Android.poll(fds, nfds_t(nfds), tmo_p)
    }

    static func pollfd(fd: FileDescriptorType, events: Int16, revents: Int16) -> Android.pollfd {
        Android.pollfd(fd: fd, events: events, revents: revents)
    }

    static func recvfrom(_ fd: FileDescriptorType, _ buffer: UnsafeMutableRawPointer!, _ nbyte: Int, _ flags: Int32, _ addr: UnsafeMutablePointer<sockaddr>!, _ len: UnsafeMutablePointer<socklen_t>!) -> Int {
        Android.recvfrom(fd, buffer, nbyte, flags, addr, len)
    }

    static func sendto(_ fd: FileDescriptorType, _ buffer: UnsafeRawPointer!, _ nbyte: Int, _ flags: Int32, _ destaddr: UnsafePointer<sockaddr>!, _ destlen: socklen_t) -> Int {
        Android.sendto(fd, buffer, nbyte, flags, destaddr, destlen)
    }

    static func recvmsg(_ fd: FileDescriptorType, _ message: UnsafeMutablePointer<msghdr>, _ flags: Int32) -> Int {
        Android.recvmsg(fd, message, flags)
    }

    static func sendmsg(_ fd: FileDescriptorType, _ message: UnsafePointer<msghdr>, _ flags: Int32) -> Int {
        Android.sendmsg(fd, message, flags)
    }
}

#endif
