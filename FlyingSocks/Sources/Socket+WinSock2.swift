//
//  Socket+WinSock2.swift
//  FlyingFox
//
//  Created by Simon Whitty on 28/03/2022.
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

let O_NONBLOCK = Int32(1)
let F_SETFL = Int32(1)
let F_GETFL = Int32(1)
var errno: Int32 {  WSAGetLastError() }
let EWOULDBLOCK = WSAEWOULDBLOCK
let EBADF = WSA_INVALID_HANDLE
let EINPROGRESS = WSAEINPROGRESS
let EISCONN = WSAEISCONN
public typealias sa_family_t = UInt8

public extension Socket {
    typealias FileDescriptorType = UInt64
}

extension Socket.FileDescriptor {
    static let invalid = Socket.FileDescriptor(rawValue: INVALID_SOCKET)
}

extension Socket {
    static let stream = Int32(SOCK_STREAM)
    static let in_addr_any = WinSDK.in_addr()

    static func makeAddressINET(port: UInt16) -> WinSDK.sockaddr_in {
        WinSDK.sockaddr_in(
            sin_family: ADDRESS_FAMILY(AF_INET),
            sin_port: port.bigEndian,
            sin_addr: in_addr_any,
            sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
        )
    }

    static func makeAddressINET6(port: UInt16) -> WinSDK.sockaddr_in6 {
        WinSDK.sockaddr_in6(
            sin6_family: ADDRESS_FAMILY(AF_INET6),
            sin6_port: port.bigEndian,
            sin6_flowinfo: 0,
            sin6_addr: in6addr_any,
            .init(sin6_scope_id: 0)
        )
    }

    static func makeAddressLoopback(port: UInt16) -> WinSDK.sockaddr_in6 {
        WinSDK.sockaddr_in6(
            sin6_family: ADDRESS_FAMILY(AF_INET6),
            sin6_port: port.bigEndian,
            sin6_flowinfo: 0,
            sin6_addr: in6addr_loopback,
            .init(sin6_scope_id: 0)
        )
    }

    static func makeAddressUnix(path: String) -> WinSDK.sockaddr_un {
        var addr = WinSDK.sockaddr_un()
        addr.sun_family = ADDRESS_FAMILY(AF_UNIX)
        let pathCount = min(path.utf8.count, 104)
        let len = UInt8(MemoryLayout<UInt8>.size + MemoryLayout<sa_family_t>.size + pathCount + 1)
        _ = withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            path.withCString {
                strncpy(ptr, $0, Int(len))
            }
        }
        return addr
    }

    static func fcntl(_ fd: FileDescriptorType, _ cmd: Int32) -> Int32 {
        return 0
    }

    static func fcntl(_ fd: FileDescriptorType, _ cmd: Int32, _ value: Int32) -> Int32 {
        var mode: UInt32 = (value & O_NONBLOCK != 0) ? 1 : 0
        guard ioctlsocket(fd, FIONBIO, &mode) == NO_ERROR else {
            return -1
        }
        return 0
    }

    static func socket(_ domain: Int32, _ type: Int32, _ protocol: Int32) -> FileDescriptorType {
        WinSDK.socket(domain, type, `protocol`)
    }

    static func socketpair(_ domain: Int32, _ type: Int32, _ protocol: Int32) -> (FileDescriptorType, FileDescriptorType) {
        (-1, -1) // no supported
    }

    static func setsockopt(_ fd: FileDescriptorType, _ level: Int32, _ name: Int32,
                           _ value: UnsafeRawPointer!, _ len: socklen_t) -> Int32 {
        WinSDK.setsockopt(fd, level, name, value.assumingMemoryBound(to: CChar.self), len)
    }

    static func getsockopt(_ fd: FileDescriptorType, _ level: Int32, _ name: Int32,
                           _ value: UnsafeMutableRawPointer!, _ len: UnsafeMutablePointer<socklen_t>!) -> Int32 {
        WinSDK.getsockopt(fd, level, name, value.assumingMemoryBound(to: CChar.self), len)
    }

    static func getpeername(_ fd: FileDescriptorType, _ addr: UnsafeMutablePointer<sockaddr>!, _ len: UnsafeMutablePointer<socklen_t>!) -> Int32 {
        WinSDK.getpeername(fd, addr, len)
    }

    static func getsockname(_ fd: FileDescriptorType, _ addr: UnsafeMutablePointer<sockaddr>!, _ len: UnsafeMutablePointer<socklen_t>!) -> Int32 {
        WinSDK.getsockname(fd, addr, len)
    }

    static func inet_ntop(_ domain: Int32, _ addr: UnsafeRawPointer!,
                          _ buffer: UnsafeMutablePointer<CChar>!, _ addrLen: socklen_t) throws {
        if WinSDK.inet_ntop(domain, addr, buffer, Int(addrLen)) == nil {
            throw SocketError.makeFailed("inet_ntop")
        }
    }

    static func inet_pton(_ domain: Int32, _ buffer: UnsafePointer<CChar>!, _ addr: UnsafeMutableRawPointer!) -> Int32 {
        WinSDK.inet_pton(domain, buffer, addr)
    }

    static func bind(_ fd: FileDescriptorType, _ addr: UnsafePointer<sockaddr>!, _ len: socklen_t) -> Int32 {
        WinSDK.bind(fd, addr, len)
    }

    static func listen(_ fd: FileDescriptorType, _ backlog: Int32) -> Int32 {
        WinSDK.listen(fd, backlog)
    }

    static func accept(_ fd: FileDescriptorType, _ addr: UnsafeMutablePointer<sockaddr>!, _ len: UnsafeMutablePointer<socklen_t>!) -> FileDescriptorType {
        WinSDK.accept(fd, addr, len)
    }

    static func connect(_ fd: FileDescriptorType, _ addr: UnsafePointer<sockaddr>!, _ len: socklen_t) -> Int32 {
        WinSDK.connect(fd, addr, len)
    }

    static func read(_ fd: FileDescriptorType, _ buffer: UnsafeMutableRawPointer!, _ nbyte: Int) -> Int {
        Int(WinSDK.recv(fd, buffer.assumingMemoryBound(to: CChar.self), Int32(nbyte), 0))
    }

    static func write(_ fd: FileDescriptorType, _ buffer: UnsafeRawPointer!, _ nbyte: Int) -> Int {
        Int(WinSDK.send(fd, buffer.assumingMemoryBound(to: CChar.self), Int32(nbyte), 0))
    }

    static func close(_ fd: FileDescriptorType) -> Int32 {
        WinSDK.closesocket(fd)
    }

    static func unlink(_ addr: UnsafePointer<CChar>!) -> Int32 {
        WinSDK.DeleteFileA(addr) ? 0 : -1
    }

    static func poll(_ fds: UnsafeMutablePointer<WinSDK.WSAPOLLFD>!, _ nfds: UInt32, _ tmo_p: Int32) -> Int32 {
        WinSDK.WSAPoll(fds, nfds, tmo_p)
    }

    static func pollfd(fd: FileDescriptorType, events: Int16, revents: Int16) -> WinSDK.WSAPOLLFD {
        WinSDK.WSAPOLLFD(fd: fd, events: events, revents: revents)
    }
}

#endif
