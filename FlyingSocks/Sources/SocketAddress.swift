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
#if canImport(WinSDK)
import WinSDK.WinSock2
#elseif canImport(Android)
import Android
#endif

#if canImport(CSystemLinux)
import CSystemLinux
#endif

public protocol SocketAddress: Sendable {
    static var family: sa_family_t { get }
}

extension SocketAddress {
    public var family: sa_family_t {
        withSockAddr { $0.pointee.sa_family }
    }

    var size: socklen_t {
        // this needs to work with sockaddr_storage, hence the switch
        switch Int32(family) {
        case AF_INET:
            socklen_t(MemoryLayout<sockaddr_in>.size)
        case AF_INET6:
            socklen_t(MemoryLayout<sockaddr_in6>.size)
        case AF_UNIX:
            socklen_t(MemoryLayout<sockaddr_un>.size)
        default:
            0
        }
    }

    public func makeStorage() -> sockaddr_storage {
        var storage = sockaddr_storage()

        withUnsafeMutablePointer(to: &storage) {
            $0.withMemoryRebound(to: Self.self, capacity: 1) {
                $0.pointee = self
            }
        }

        return storage
    }
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

    #if canImport(Glibc) || canImport(Musl) || canImport(Android)
    static func unix(abstractNamespace: String) -> Self {
        Socket.makeAbstractNamespaceUnix(name: abstractNamespace)
    }
    #endif
}

#if compiler(>=6.0)
extension sockaddr_storage: SocketAddress, @retroactive @unchecked Sendable {
    public static let family = sa_family_t(AF_UNSPEC)
}

extension sockaddr_in: SocketAddress, @retroactive @unchecked Sendable {
    public static let family = sa_family_t(AF_INET)
}

extension sockaddr_in6: SocketAddress, @retroactive @unchecked Sendable {
    public static let family = sa_family_t(AF_INET6)
}

extension sockaddr_un: SocketAddress, @retroactive @unchecked Sendable {
    public static let family = sa_family_t(AF_UNIX)
}
#else
extension sockaddr_storage: SocketAddress, @unchecked Sendable {
    public static let family = sa_family_t(AF_UNSPEC)
}

extension sockaddr_in: SocketAddress, @unchecked Sendable {
    public static let family = sa_family_t(AF_INET)
}

extension sockaddr_in6: SocketAddress, @unchecked Sendable {
    public static let family = sa_family_t(AF_INET6)
}

extension sockaddr_un: SocketAddress, @unchecked Sendable {
    public static let family = sa_family_t(AF_UNIX)
}
#endif

public extension SocketAddress {
    static func make(from storage: sockaddr_storage) throws -> Self {
        guard self is sockaddr_storage.Type || storage.ss_family == family else {
            throw SocketError.unsupportedAddress
        }
        var storage = storage
        return withUnsafePointer(to: &storage) {
            $0.withMemoryRebound(to: Self.self, capacity: 1) {
                $0.pointee
            }
        }
    }
}

extension Socket {

    public enum Address: Sendable, Hashable {
        case ip4(String, port: UInt16)
        case ip6(String, port: UInt16)
        case unix(String)
    }

    public static func makeAddress(from addr: sockaddr_storage) throws -> Address {
        switch Int32(addr.ss_family) {
        case AF_INET:
            var addr_in = try sockaddr_in.make(from: addr)
            let maxLength = socklen_t(INET_ADDRSTRLEN)
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(maxLength))
            defer { buffer.deallocate() }
            try Socket.inet_ntop(AF_INET, &addr_in.sin_addr, buffer, maxLength)
            return .ip4(String(cString: buffer), port: UInt16(addr_in.sin_port).byteSwapped)

        case AF_INET6:
            var addr_in6 = try sockaddr_in6.make(from: addr)
            let maxLength = socklen_t(INET6_ADDRSTRLEN)
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(maxLength))
            defer { buffer.deallocate() }
            try Socket.inet_ntop(AF_INET6, &addr_in6.sin6_addr, buffer, maxLength)
            return .ip6(String(cString: buffer), port: UInt16(addr_in6.sin6_port).byteSwapped)

        case AF_UNIX:
            var sockaddr_un = try sockaddr_un.make(from: addr)
            return withUnsafePointer(to: &sockaddr_un.sun_path.0) {
                return .unix(String(cString: $0))
            }
        default:
            throw SocketError.unsupportedAddress
        }
    }

    public static func unlink(_ address: sockaddr_un) throws {
        var address = address
        guard Socket.unlink(&address.sun_path.0) == 0 else {
            throw SocketError.makeFailed("unlink")
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
}

public struct AnySocketAddress: Sendable, SocketAddress {
    public static var family: sa_family_t {
        sa_family_t(AF_UNSPEC)
    }

    private var storage: sockaddr_storage

    public init(_ sa: any SocketAddress) {
        storage = sa.makeStorage()
    }
}

public extension SocketAddress {
    func withSockAddr<T>(_ body: (_ sa: UnsafePointer<sockaddr>) throws -> T) rethrows -> T {
        try withUnsafePointer(to: self) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                try body(sa)
            }
        }
    }

    mutating func withMutableSockAddr<T>(_ body: (_ sa: UnsafeMutablePointer<sockaddr>) throws -> T) rethrows -> T {
        try withUnsafeMutablePointer(to: &self) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                try body(sa)
            }
        }
    }
}
