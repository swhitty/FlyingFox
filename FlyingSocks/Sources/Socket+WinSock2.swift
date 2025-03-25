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
import Foundation

let O_NONBLOCK = Int32(1)
let F_SETFL = Int32(1)
let F_GETFL = Int32(1)
var errno: Int32 {  WSAGetLastError() }
let EWOULDBLOCK = WSAEWOULDBLOCK
let EBADF = WSAENOTSOCK
let EINPROGRESS = WSAEINPROGRESS
let EISCONN = WSAEISCONN
public typealias sa_family_t = ADDRESS_FAMILY

public extension Socket {
    typealias FileDescriptorType = UInt64
    typealias IovLengthType = UInt
    typealias ControlMessageHeaderLengthType = DWORD
    typealias IPv4InterfaceIndexType = ULONG
    typealias IPv6InterfaceIndexType = ULONG
}

extension Socket.FileDescriptor {
    static let invalid = Socket.FileDescriptor(rawValue: INVALID_SOCKET)
}

extension Socket {
    static let stream = Int32(SOCK_STREAM)
    static let datagram = Int32(SOCK_DGRAM)
    static let in_addr_any = WinSDK.in_addr()
    static let ipproto_ip = Int32(IPPROTO_IP)
    static let ipproto_ipv6 = Int32(IPPROTO_IPV6.rawValue)
    static let ip_pktinfo = Int32(IP_PKTINFO)
    static let ipv6_pktinfo = Int32(IPV6_PKTINFO)

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
        guard fd != INVALID_SOCKET else { return -1 }
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
        guard domain == AF_UNIX else { return (INVALID_SOCKET, INVALID_SOCKET) }
        func makeTempUnixPath() -> URL {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("socketpair_\(UUID().uuidString.prefix(8)).sock", isDirectory: false)
            try? FileManager.default.removeItem(at: tempURL)
            return tempURL
        }

        if type == SOCK_STREAM {
            let tempURL = makeTempUnixPath()
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let listener = socket(domain, type, `protocol`)

            guard listener != INVALID_SOCKET else { return (INVALID_SOCKET, INVALID_SOCKET) }

            let addr = makeAddressUnix(path: tempURL.path)

            let bindListenerResult = addr.withSockAddr {
                bind(listener, $0, addr.size)
            }

            guard bindListenerResult == 0 else { return (INVALID_SOCKET, INVALID_SOCKET) }

            guard listen(listener, 1) == 0 else {
                _ = close(listener)
                return (INVALID_SOCKET, INVALID_SOCKET) 
            }

            let connector = socket(domain, type, `protocol`)

            guard connector != INVALID_SOCKET else { 
                _ = close(listener)
                return (INVALID_SOCKET, INVALID_SOCKET) 
            }

            let connectResult = addr.withSockAddr { connect(connector, $0, addr.size) == 0 }

            guard connectResult else {
                _ = close(listener)
                _ = close(connector)
                return (INVALID_SOCKET, INVALID_SOCKET)
            }

            let acceptor = accept(listener, nil, nil)
            guard acceptor != INVALID_SOCKET else {
                _ = close(listener)
                _ = close(connector)
                return (INVALID_SOCKET, INVALID_SOCKET)
            }

            _ = close(listener)

            return (connector, acceptor)
        } else if type == SOCK_DGRAM {
            return (INVALID_SOCKET, INVALID_SOCKET)
            // unsupported at this time: https://github.com/microsoft/WSL/issues/5272
            // let tempURL1 = makeTempUnixPath()
            // let tempURL2 = makeTempUnixPath()
            // guard FileManager.default.createFile(atPath: tempURL1.path, contents: nil) else { return (INVALID_SOCKET, INVALID_SOCKET) }
            // guard FileManager.default.createFile(atPath: tempURL2.path, contents: nil) else { return (INVALID_SOCKET, INVALID_SOCKET) }

            // defer { try? FileManager.default.removeItem(at: tempURL1) }
            // defer { try? FileManager.default.removeItem(at: tempURL2) }

            // let socket1 = socket(domain, type, `protocol`)
            // let socket2 = socket(domain, type, `protocol`)

            // guard socket1 != INVALID_SOCKET, socket2 != INVALID_SOCKET else { 
            //     if socket1 != INVALID_SOCKET { _ = close(socket1) }
            //     if socket2 != INVALID_SOCKET { _ = close(socket2) }
            //     return (INVALID_SOCKET, INVALID_SOCKET) 
            // }

            // let addr1 = makeAddressUnix(path: tempURL1.path)
            // let addr2 = makeAddressUnix(path: tempURL2.path)

            // guard addr1.withSockAddr({ bind(socket1, $0, addr1.size) }) == 0 else { 
            //     _ = close(socket1)
            //     _ = close(socket2)
            //     return (INVALID_SOCKET, INVALID_SOCKET) 
            // }

            // guard addr2.withSockAddr({ bind(socket2, $0, addr2.size) }) == 0 else {
            //     _ = close(socket1)
            //     _ = close(socket2)
            //     return (INVALID_SOCKET, INVALID_SOCKET)
            // }

            // guard addr2.withSockAddr({ connect(socket1, $0, addr2.size) }) == 0 else {
            //     _ = close(socket1)
            //     _ = close(socket2)
            //     return (INVALID_SOCKET, INVALID_SOCKET)
            // }

            // guard addr1.withSockAddr({ connect(socket2, $0, addr1.size) }) == 0 else {
            //     _ = close(socket1)
            //     _ = close(socket2)
            //     return (INVALID_SOCKET, INVALID_SOCKET)
            // }

            // return (socket1, socket2)
        } else {
            return (INVALID_SOCKET, INVALID_SOCKET)
        }
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

    static func recvfrom(_ fd: FileDescriptorType, _ buffer: UnsafeMutableRawPointer!, _ nbyte: Int, _ flags: Int32, _ addr: UnsafeMutablePointer<sockaddr>!, _ len: UnsafeMutablePointer<socklen_t>!) -> Int {
        Int(WinSDK.recvfrom(fd, buffer, Int32(nbyte), flags, addr, len))
    }

    static func sendto(_ fd: FileDescriptorType, _ buffer: UnsafeRawPointer!, _ nbyte: Int, _ flags: Int32, _ destaddr: UnsafePointer<sockaddr>!, _ destlen: socklen_t) -> Int {
        Int(WinSDK.sendto(fd, buffer, Int32(nbyte), flags, destaddr, destlen))
    }
}

public extension in_addr {
    var s_addr: UInt32 {
        get {
            S_un.S_addr
        } set {
            S_un.S_addr = newValue
        }
    }
}

private extension URL {
    var fileSystemRepresentation: String {
        withUnsafeFileSystemRepresentation {
            String(cString: $0!)
        }
    }
}

#endif
