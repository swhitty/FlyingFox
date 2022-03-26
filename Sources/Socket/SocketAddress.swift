//
//  Socket+Address.swift
//  FlyingFox
//
//  Created by Simon Whitty on 15/03/2022.
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

import Foundation

public protocol SocketAddress {
    static var family: sa_family_t { get }
}

public extension SocketAddress where Self == sockaddr_in {

    static func inet(port: UInt16) -> Self {
        Socket.makeAddressINET(port: port)
    }

    static func inet(ip4: String, port: UInt16) throws -> Self {
        var addr = Socket.makeAddressINET(port: port)
        addr.sin_addr = try Socket.makeInAddr(fromIP4: ip4)
        return addr
    }
}

public extension SocketAddress where Self == sockaddr_in6 {

    static func inet6(port: UInt16) -> Self {
        Socket.makeAddressINET6(port: port)
    }

    static func inet6(ip6: String, port: UInt16) throws -> Self {
        var addr = Socket.makeAddressINET6(port: port)
        addr.sin6_addr = try Socket.makeInAddr(fromIP6: ip6)
        return addr
    }

    static func loopback(port: UInt16) -> Self {
        Socket.makeAddressLoopback(port: port)
    }
}

public extension SocketAddress where Self == sockaddr_un {

    static func unix(path: String) -> Self {
        Socket.makeAddressUnix(path: path)
    }
}

extension sockaddr_in: SocketAddress {
    public static let family = sa_family_t(AF_INET)
}

extension sockaddr_in6: SocketAddress {
    public static let family = sa_family_t(AF_INET6)
}

extension sockaddr_un: SocketAddress {
    public static let family = sa_family_t(AF_UNIX)
}

public extension SocketAddress {
    static func make(from storage: sockaddr_storage) throws -> Self {
        guard storage.ss_family == family else {
            throw SocketError.unsupportedAddress
        }
        var storage = storage
        return withUnsafePointer(to: &storage) {
            $0.withMemoryRebound(to: Self.self, capacity: 1) {
                $0.pointee
            }
        }
    }

    func makeStorage() -> sockaddr_storage {
        var addr = self
        return withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr_storage.self, capacity: 1) {
                $0.pointee
            }
        }
    }
}

extension Socket {

    enum Address: Hashable {
        case ip4(String, port: UInt16)
        case ip6(String, port: UInt16)
        case unix(String)
    }

    static func makeAddress(from addr: sockaddr_storage) throws -> Address {
        switch Int32(addr.ss_family) {
        case AF_INET:
            var addr_in = try sockaddr_in.make(from: addr)
            let maxLength = socklen_t(INET_ADDRSTRLEN)
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(maxLength))
            try Socket.inet_ntop(AF_INET, &addr_in.sin_addr, buffer, maxLength)
            return .ip4(String(cString: buffer), port: UInt16(addr_in.sin_port).byteSwapped)

        case AF_INET6:
            var addr_in6 = try sockaddr_in6.make(from: addr)
            let maxLength = socklen_t(INET6_ADDRSTRLEN)
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(maxLength))
            try Socket.inet_ntop(AF_INET6, &addr_in6.sin6_addr, buffer, maxLength)
            return .ip6(String(cString: buffer), port: UInt16(addr_in6.sin6_port).byteSwapped)

        case AF_UNIX:
            var sockaddr_un = try sockaddr_un.make(from: addr)
            return .unix(String(cString: &sockaddr_un.sun_path.0))

        default:
            throw SocketError.unsupportedAddress
        }
    }

    static func makeAddressINET(fromIP4 ip: String, port: UInt16) throws -> sockaddr_in {
        var address = Socket.makeAddressINET(port: port)
        address.sin_addr = try Socket.makeInAddr(fromIP4: ip)
        return address
    }

    static func makeInAddr(fromIP4 address: String) throws -> in_addr {
        var addr = in_addr()
        guard address.withCString({ Socket.inet_pton(AF_INET, $0, &addr) }) == 1 else {
            throw SocketError.makeFailed("inet_pton AF_INET")
        }
        return addr
    }

    static func makeInAddr(fromIP6 address: String) throws -> in6_addr {
        var addr = in6_addr()
        guard address.withCString({ Socket.inet_pton(AF_INET6, $0, &addr) }) == 1 else {
            throw SocketError.makeFailed("inet_pton AF_INET6")
        }
        return addr
    }

    static func unlink(_ address: sockaddr_un) throws {
        var address = address
        guard Socket.unlink(&address.sun_path.0) == 0 else {
            throw SocketError.makeFailed("unlink")
        }
    }
}
