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

    static let stream = Int32(SOCK_STREAM)

    static func socket(_ domain: Int32, _ type: Int32, _ protocol: Int32) -> Int32 {
        Darwin.socket(domain, type, `protocol`)
    }

    static func fcntl(_ fd: Int32, _ cmd: Int32) -> Int32 {
        Darwin.fcntl(fd, cmd)
    }

    static func fcntl(_ fd: Int32, _ cmd: Int32, _ value: Int32) -> Int32 {
        Darwin.fcntl(fd, cmd, value)
    }

    static func setsockopt(_ fd: Int32, _ level: Int32, _ name: Int32,
                           _ value: UnsafeRawPointer!, _ len: socklen_t) -> Int32 {
        Darwin.setsockopt(fd, level, name, value, len)
    }

    static func getsockopt(_ fd: Int32, _ level: Int32, _ name: Int32,
                           _ value: UnsafeMutableRawPointer!, _ len: UnsafeMutablePointer<socklen_t>!) -> Int32 {
        Darwin.getsockopt(fd, level, name, value, len)
    }

    static func sockaddr_in6(port: UInt16) -> sockaddr_in6 {
        Darwin.sockaddr_in6(
            sin6_len: UInt8(MemoryLayout<sockaddr_in6>.stride),
            sin6_family: sa_family_t(AF_INET6),
            sin6_port: port.bigEndian,
            sin6_flowinfo: 0,
            sin6_addr: in6addr_any,
            sin6_scope_id: 0
        )
    }

    static func getpeername(_ fd: Int32, _ addr: UnsafeMutablePointer<sockaddr>!, _ len: UnsafeMutablePointer<socklen_t>!) -> Int32 {
        Darwin.getpeername(fd, addr, len)
    }

    static func getnameinfo(_ addr: UnsafePointer<sockaddr>!, _ addrLen: socklen_t,
                            _ buffer: UnsafeMutablePointer<CChar>!, _ bufferLen: socklen_t,
                            _ serv: UnsafeMutablePointer<CChar>!, _ servLen: socklen_t,
                            _ flags: Int32) -> Int32 {
        Darwin.getnameinfo(addr, addrLen, buffer, bufferLen, serv, servLen, flags)
    }

    static func bind(_ fd: Int32, _ addr: UnsafePointer<sockaddr>!, _ len: socklen_t) -> Int32 {
        Darwin.bind(fd, addr, len)
    }

    static func listen(_ fd: Int32, _ backlog: Int32) -> Int32 {
        Darwin.listen(fd, backlog)
    }

    static func accept(_ fd: Int32, _ addr: UnsafeMutablePointer<sockaddr>!, _ len: UnsafeMutablePointer<socklen_t>!) -> Int32 {
        Darwin.accept(fd, addr, len)
    }

    static func read(_ fd: Int32, _ buffer: UnsafeMutableRawPointer!, _ nbyte: Int) -> Int {
        Darwin.read(fd, buffer, nbyte)
    }

    static func write(_ fd: Int32, _ buffer: UnsafeRawPointer!, _ nbyte: Int) -> Int {
        Darwin.write(fd, buffer, nbyte)
    }

    static func close(_ fd: Int32) -> Int32 {
        Darwin.close(fd)
    }

    static func poll(_ fds: UnsafeMutablePointer<pollfd>!, _ nfds: nfds_t, _ tmo_p: Int32) {
        Darwin.poll(fds, nfds, tmo_p)
    }

    static func hasEvent(_ event: Int32, in revents: Int16) -> Bool {
        revents & Int16(event) != 0
    }
}

#endif
