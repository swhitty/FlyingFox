//
//  SocketAddressTests.swift
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

@testable import FlyingSocks
import Testing
import Foundation

struct SocketAddressTests {

    @Test
    func INET_IsCorrectlyDecodedFromStorage() throws {
        let storage = sockaddr_in
            .inet(port: 8001)
            .makeStorage()

        #expect(
            try sockaddr_in.make(from: storage)
                .sin_port
                .bigEndian == 8001
        )
    }

    @Test
    func INET_ThrowsInvalidAddress_WhenFamilyIncorrect() {
        let storage = sockaddr_un
            .unix(path: "/var")
            .makeStorage()

        #expect(throws: SocketError.unsupportedAddress) {
            try sockaddr_in.make(from: storage)
        }
    }

    @Test
    func address_DecodesIP4() throws {
        let addr = try Socket.makeAddressINET(fromIP4: "192.168.0.1",
                                              port: 1080)

        #expect(
            try Socket.makeAddress(from: addr.makeStorage()) == .ip4("192.168.0.1", port: 1080)
        )
    }

    @Test
    func invalidIP4_ThrowsError() {
        #expect(throws: SocketError.self) {
            try Socket.makeInAddr(fromIP4: "192.168.0")
        }
        #expect(throws: SocketError.self) {
            try sockaddr_in.inet(ip4: "::1", port: 80)
        }
    }

    @Test
    func INET6_IsCorrectlyDecodedFromStorage() throws {
        let storage = sockaddr_in6
            .inet6(port: 8080)
            .makeStorage()

        #expect(
            try sockaddr_in6.make(from: storage)
                .sin6_port
                .bigEndian == 8080
        )
    }

    @Test
    func INET6_ThrowsInvalidAddress_WhenFamilyIncorrect() throws {
        let storage = sockaddr_un
            .unix(path: "/var")
            .makeStorage()

        #expect(throws: SocketError.unsupportedAddress) {
            try sockaddr_in6.make(from: storage)
        }
    }

    @Test
    func address_DecodesIP6() throws {
        var addr = Socket.makeAddressINET6(port: 5010)
        addr.sin6_addr = try Socket.makeInAddr(fromIP6: "::1")

        #expect(
            try Socket.makeAddress(from: addr.makeStorage()) == .ip6("::1", port: 5010)
        )
    }

    @Test
    func loopbackAddress_DecodesIP6() throws {
        let loopback = sockaddr_in6.loopback(port: 5060)

        #expect(
            try Socket.makeAddress(from: loopback.makeStorage()) == .ip6("::1", port: 5060)
        )
    }

    @Test
    func invalidIP6_ThrowsError() {
        #expect(throws: SocketError.self) {
            try Socket.makeInAddr(fromIP6: "192.168.0")
        }

        #expect(throws: SocketError.self) {
            try sockaddr_in6.inet6(ip6: ":10:::::", port: 80)
        }
    }

    @Test
    func unix_IsCorrectlyDecodedFromStorage() throws {
        let storage = sockaddr_un
            .unix(path: "/var")
            .makeStorage()

        var unix = try sockaddr_un.make(from: storage)
        let path = withUnsafePointer(to: &unix.sun_path.0) {
            return String(cString: $0)
        }
        #expect(
            path == "/var"
        )
    }

    #if canImport(Glibc) || canImport(Musl) || canImport(Android)
    @Test
    func unixAbstractNamespace_IsCorrectlyDecodedFromStorage() throws {
        let storage = sockaddr_un
            .unix(abstractNamespace: "mygreatnamespace")
            .makeStorage()

        var unix = try sockaddr_un.make(from: storage)
        let path = withUnsafePointer(to: &unix.sun_path.1) {
            return String(cString: $0)
        }
        #expect(
            path == "mygreatnamespace"
        )
    }
    #endif

    @Test
    func unix_ThrowsInvalidAddress_WhenFamilyIncorrect() {
        let storage = sockaddr_in6
            .inet6(port: 8080)
            .makeStorage()

        #expect(throws: SocketError.unsupportedAddress) {
            try sockaddr_un.make(from: storage)
        }
    }

    @Test
    func INET4_CheckSize() throws {
        let sin = sockaddr_in.inet(port: 8001)
        #expect(
            sin.size == socklen_t(MemoryLayout<sockaddr_in>.size)
        )
    }

    @Test
    func INET6_CheckSize() throws {
        let sin6 = sockaddr_in6.inet6(port: 8001)
        #expect(
            sin6.size == socklen_t(MemoryLayout<sockaddr_in6>.size)
        )
    }

    @Test
    func unix_CheckSize() throws {
        let sun = sockaddr_un.unix(path: "/var/foo")
        #expect(
            sun.size == socklen_t(MemoryLayout<sockaddr_un>.size)
        )
    }

    #if canImport(Glibc) || canImport(Musl) || canImport(Android)
    @Test
    func unixAbstractNamespace_CheckSize() throws {
        let sun = sockaddr_un.unix(abstractNamespace: "some_great_namespace")
        #expect(
            sun.size == socklen_t(MemoryLayout<sockaddr_un>.size)
        )
    }
    #endif

    @Test
    func unknown_CheckSize() throws {
        var sa = sockaddr()
        sa.sa_family = sa_family_t(AF_UNSPEC)

        #expect(
            sa.size == 0
        )
    }

    @Test
    func unlinkUnix_Throws_WhenPathIsInvalid() {
        #expect(throws: SocketError.self) {
            try Socket.unlink(sockaddr_un())
        }
    }

    @Test
    func IPX_ThrowsInvalidAddress() {
        var storage = sockaddr_storage()
        storage.ss_family = sa_family_t(AF_IPX)

        #expect(throws: SocketError.unsupportedAddress) {
            try Socket.makeAddress(from: storage)
        }
    }

    @Test
    func sockaddrInToStorageConversion() throws {
        var addrIn = sockaddr_in()
        addrIn.sin_family = sa_family_t(AF_INET)
        addrIn.sin_port = UInt16(8080).bigEndian
        addrIn.sin_addr = try Socket.makeInAddr(fromIP4: "192.168.1.1")

        let storage = addrIn.makeStorage()

        #expect(storage.ss_family == sa_family_t(AF_INET))
        withUnsafeBytes(of: addrIn) { addrInPtr in
            let storagePtr = addrInPtr.bindMemory(to: sockaddr_storage.self)
            #expect(storagePtr.baseAddress!.pointee.ss_family == sa_family_t(AF_INET))
            let sockaddrInPtr = addrInPtr.bindMemory(to: sockaddr_in.self)
            #expect(sockaddrInPtr.baseAddress!.pointee.sin_port == addrIn.sin_port)
            #expect(sockaddrInPtr.baseAddress!.pointee.sin_addr.s_addr == addrIn.sin_addr.s_addr)
        }
    }

    @Test
    func sockaddrIn6ToStorageConversion() throws {
        var addrIn6 = sockaddr_in6()
        addrIn6.sin6_family = sa_family_t(AF_INET6)
        addrIn6.sin6_port = UInt16(9090).bigEndian
        addrIn6.sin6_addr = try Socket.makeInAddr(fromIP6: "fe80::1")

        let storage = addrIn6.makeStorage()

        #expect(storage.ss_family == sa_family_t(AF_INET6))
        #expect(storage.ss_family == addrIn6.sin6_family)

        withUnsafeBytes(of: addrIn6) { addrIn6Ptr in
            let storagePtr = addrIn6Ptr.bindMemory(to: sockaddr_storage.self)
            #expect(storagePtr.baseAddress!.pointee.ss_family == sa_family_t(AF_INET6))
            let sockaddrIn6Ptr = addrIn6Ptr.bindMemory(to: sockaddr_in6.self)
            #expect(sockaddrIn6Ptr.baseAddress!.pointee.sin6_port == addrIn6.sin6_port)
            let addrArray = withUnsafeBytes(of: sockaddrIn6Ptr.baseAddress!.pointee.sin6_addr) {
                Array($0.bindMemory(to: UInt8.self))
            }
            let expectedArray = withUnsafeBytes(of: addrIn6.sin6_addr) {
                Array($0.bindMemory(to: UInt8.self))
            }
            #expect(addrArray == expectedArray)
        }
    }

    @Test
    func sockaddrUnToStorageConversion() {
        var addrUn = sockaddr_un()
        addrUn.sun_family = sa_family_t(AF_UNIX)
        let path = "/tmp/socket"
        _ = path.withCString { pathPtr in
            memcpy(&addrUn.sun_path, pathPtr, path.count + 1)
        }

        let storage = addrUn.makeStorage()

        #expect(storage.ss_family == sa_family_t(AF_UNIX))
        let addrUnBytes = withUnsafeBytes(of: addrUn) { Data($0) }
        let storageBytes = withUnsafeBytes(of: storage) { Data($0) }
        let storageSockaddrUnBytes = storageBytes[0..<MemoryLayout<sockaddr_un>.size]
        #expect(addrUnBytes == storageSockaddrUnBytes)
    }

    @Test
    func invalidAddressFamily() {
        var storage = sockaddr_storage()
        storage.ss_family = sa_family_t(AF_APPLETALK) // Invalid for our purpose

        #expect(throws: SocketError.unsupportedAddress) {
            try sockaddr_in.make(from: storage)
        }

        #expect(throws: SocketError.unsupportedAddress) {
            try sockaddr_in6.make(from: storage)
        }

        #expect(throws: SocketError.unsupportedAddress) {
            try sockaddr_un.make(from: storage)
        }
    }

    @Test
    func maximumPathLengthForUnixDomainSocket() {
        var addrUn = sockaddr_un()
        addrUn.sun_family = sa_family_t(AF_UNIX)
        let maxPathLength = MemoryLayout<sockaddr_un>.size - MemoryLayout<sa_family_t>.size - 1
        let maxPath = String(repeating: "a", count: maxPathLength)
        _ = maxPath.withCString { pathPtr in
            memcpy(&addrUn.sun_path, pathPtr, maxPath.count + 1)
        }

        let storage = addrUn.makeStorage()

        #expect(storage.ss_family == sa_family_t(AF_UNIX))
        let addrUnBytes = withUnsafeBytes(of: addrUn) { Data($0) }
        let storageBytes = withUnsafeBytes(of: storage) { Data($0) }
        let storageAddrUnBytes = storageBytes.prefix(MemoryLayout<sockaddr_un>.size)
        #expect(addrUnBytes == storageAddrUnBytes)
    }

    @Test
    func memoryBoundsInMakeStorage() {
        var addrIn = sockaddr_in()
        addrIn.sin_family = sa_family_t(AF_INET)
        
        let storage = addrIn.makeStorage()

        let addrSize = MemoryLayout<sockaddr_in>.size
        let storageSize = MemoryLayout<sockaddr_storage>.size
        #expect(addrSize <= storageSize)

        withUnsafeBytes(of: addrIn) { addrInPtr in
            let addrInBytes = addrInPtr.bindMemory(to: UInt8.self).baseAddress!
            withUnsafeBytes(of: storage) { storagePtr in
                let storageBytes = storagePtr.bindMemory(to: UInt8.self).baseAddress!
                for i in 0..<addrSize {
                    #expect(addrInBytes[i] == storageBytes[i], "Mismatch at byte \(i)")
                }
            }
        }
    }

    @Test
    func testTypeErasedSockAddress() throws {
        var addrIn6 = sockaddr_in6()
        addrIn6.sin6_family = sa_family_t(AF_INET6)
        addrIn6.sin6_port = UInt16(9090).bigEndian
        addrIn6.sin6_addr = try Socket.makeInAddr(fromIP6: "fe80::1")

        let storage = AnySocketAddress(addrIn6)

        #expect(storage.family == sa_family_t(AF_INET6))
        #expect(storage.family == addrIn6.sin6_family)

        withUnsafeBytes(of: addrIn6) { addrIn6Ptr in
            let storagePtr = addrIn6Ptr.bindMemory(to: sockaddr_storage.self)
            #expect(storagePtr.baseAddress!.pointee.ss_family == sa_family_t(AF_INET6))
            let sockaddrIn6Ptr = addrIn6Ptr.bindMemory(to: sockaddr_in6.self)
            #expect(sockaddrIn6Ptr.baseAddress!.pointee.sin6_port == addrIn6.sin6_port)
            let addrArray = withUnsafeBytes(of: sockaddrIn6Ptr.baseAddress!.pointee.sin6_addr) {
                Array($0.bindMemory(to: UInt8.self))
            }
            let expectedArray = withUnsafeBytes(of: addrIn6.sin6_addr) {
                Array($0.bindMemory(to: UInt8.self))
            }
            #expect(addrArray == expectedArray)
        }

        storage.withSockAddr { sa in
            #expect(sa.pointee.sa_family == sa_family_t(AF_INET6))
        }

        addrIn6.withSockAddr { sa in
            #expect(sa.pointee.sa_family == sa_family_t(AF_INET6))
        }
    }
}

// this is a bit ugly but necessary to get unknown_CheckSize() to function
extension sockaddr: SocketAddress, @retroactive @unchecked Sendable {
    public static var family: sa_family_t { sa_family_t(AF_UNSPEC) }
}
