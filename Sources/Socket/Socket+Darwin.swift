//
//  Socket+Darwin.swift
//  FlyingFox
//
//  Created by Simon Whitty on 19/02/2022.
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

#if canImport(Darwin)
import Darwin

extension Socket {

    typealias FileDescriptorType = Int32
    static let stream = Int32(SOCK_STREAM)
    static let in_addr_any = Darwin.in_addr(s_addr: Darwin.in_addr_t(0))

    static func makeAddressINET(port: UInt16) -> Darwin.sockaddr_in {
        Darwin.sockaddr_in(
            sin_len: UInt8(MemoryLayout<sockaddr_in>.stride),
            sin_family: sa_family_t(AF_INET),
            sin_port: port.bigEndian,
            sin_addr: in_addr_any,
            sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
        )
    }

    static func makeAddressINET6(port: UInt16) -> Darwin.sockaddr_in6 {
        Darwin.sockaddr_in6(
            sin6_len: UInt8(MemoryLayout<sockaddr_in6>.stride),
            sin6_family: sa_family_t(AF_INET6),
            sin6_port: port.bigEndian,
            sin6_flowinfo: 0,
            sin6_addr: in6addr_any,
            sin6_scope_id: 0
        )
    }

    static func makeAddressLoopback(port: UInt16) -> Darwin.sockaddr_in6 {
        Darwin.sockaddr_in6(
            sin6_len: UInt8(MemoryLayout<sockaddr_in6>.stride),
            sin6_family: sa_family_t(AF_INET6),
            sin6_port: port.bigEndian,
            sin6_flowinfo: 0,
            sin6_addr: in6addr_loopback,
            sin6_scope_id: 0
        )
    }

    static func makeAddressUnix(path: String) -> Darwin.sockaddr_un {
        var addr = Darwin.sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathCount = min(path.utf8.count, 104)
        let len = UInt8(MemoryLayout<UInt8>.size + MemoryLayout<sa_family_t>.size + pathCount + 1)
        _ = withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            path.withCString {
                strncpy(ptr, $0, Int(len))
            }
        }
        addr.sun_len = len
        return addr
    }

    static func socket(_ domain: Int32, _ type: Int32, _ protocol: Int32) -> FileDescriptorType {
        Darwin.socket(domain, type, `protocol`)
    }

    static func fcntl(_ fd: FileDescriptorType, _ cmd: Int32) -> Int32 {
        Darwin.fcntl(fd, cmd)
    }

    static func fcntl(_ fd: FileDescriptorType, _ cmd: Int32, _ value: Int32) -> Int32 {
        Darwin.fcntl(fd, cmd, value)
    }

    static func setsockopt(_ fd: FileDescriptorType, _ level: Int32, _ name: Int32,
                           _ value: UnsafeRawPointer!, _ len: socklen_t) -> Int32 {
        Darwin.setsockopt(fd, level, name, value, len)
    }

    static func getsockopt(_ fd: FileDescriptorType, _ level: Int32, _ name: Int32,
                           _ value: UnsafeMutableRawPointer!, _ len: UnsafeMutablePointer<socklen_t>!) -> Int32 {
        Darwin.getsockopt(fd, level, name, value, len)
    }

    static func getpeername(_ fd: FileDescriptorType, _ addr: UnsafeMutablePointer<sockaddr>!, _ len: UnsafeMutablePointer<socklen_t>!) -> Int32 {
        Darwin.getpeername(fd, addr, len)
    }

    static func getsockname(_ fd: FileDescriptorType, _ addr: UnsafeMutablePointer<sockaddr>!, _ len: UnsafeMutablePointer<socklen_t>!) -> Int32 {
        Darwin.getsockname(fd, addr, len)
    }

    static func inet_ntop(_ domain: Int32, _ addr: UnsafeRawPointer!,
                          _ buffer: UnsafeMutablePointer<CChar>!, _ addrLen: socklen_t) throws {
        if Darwin.inet_ntop(domain, addr, buffer, addrLen) == nil {
            throw SocketError.makeFailed("inet_ntop")
        }
    }

    static func inet_pton(_ domain: Int32, _ buffer: UnsafePointer<CChar>!, _ addr: UnsafeMutableRawPointer!) -> Int32 {
        Darwin.inet_pton(domain, buffer, addr)
    }

    static func bind(_ fd: FileDescriptorType, _ addr: UnsafePointer<sockaddr>!, _ len: socklen_t) -> Int32 {
        Darwin.bind(fd, addr, len)
    }

    static func listen(_ fd: FileDescriptorType, _ backlog: Int32) -> Int32 {
        Darwin.listen(fd, backlog)
    }

    static func accept(_ fd: FileDescriptorType, _ addr: UnsafeMutablePointer<sockaddr>!, _ len: UnsafeMutablePointer<socklen_t>!) -> Int32 {
        Darwin.accept(fd, addr, len)
    }

    static func connect(_ fd: FileDescriptorType, _ addr: UnsafePointer<sockaddr>!, _ len: socklen_t) -> Int32 {
        Darwin.connect(fd, addr, len)
    }

    static func read(_ fd: FileDescriptorType, _ buffer: UnsafeMutableRawPointer!, _ nbyte: Int) -> Int {
        Darwin.read(fd, buffer, nbyte)
    }

    static func write(_ fd: FileDescriptorType, _ buffer: UnsafeRawPointer!, _ nbyte: Int) -> Int {
        Darwin.write(fd, buffer, nbyte)
    }

    static func close(_ fd: FileDescriptorType) -> Int32 {
        Darwin.close(fd)
    }

    static func unlink(_ addr: UnsafePointer<CChar>!) -> Int32 {
        return Darwin.unlink(addr)
    }

    static func poll(_ fds: UnsafeMutablePointer<pollfd>!, _ nfds: nfds_t, _ tmo_p: Int32) -> Int32 {
        Darwin.poll(fds, nfds, tmo_p)
    }

    static func pollfd(fd: FileDescriptorType, events: Int16, revents: Int16) -> Darwin.pollfd {
        Darwin.pollfd(fd: fd, events: events, revents: revents)
    }
}

#endif
