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
import XCTest
import Foundation

final class SocketAddressTests: XCTestCase {

    func testINET_IsCorrectlyDecodedFromStorage() {
        let storage = sockaddr_in
            .inet(port: 8001)
            .makeStorage()

        XCTAssertEqual(
            try sockaddr_in.make(from: storage)
                .sin_port
                .bigEndian,
            8001
        )
    }

    func testINET_ThrowsInvalidAddress_WhenFamilyIncorrect() {
        let storage = sockaddr_un
            .unix(path: "/var")
            .makeStorage()

        XCTAssertThrowsError(
            try sockaddr_in.make(from: storage),
            of: SocketError.self
        ) {
            XCTAssertEqual($0, .unsupportedAddress)
        }
    }

    func testAddress_DecodesIP4() throws {
        let addr = try Socket.makeAddressINET(fromIP4: "192.168.0.1",
                                              port: 1080)

        XCTAssertEqual(
            try Socket.makeAddress(from: addr.makeStorage()),
            .ip4("192.168.0.1", port: 1080)
        )
    }

    func testInvalidIP4_ThrowsError() {
        XCTAssertThrowsError(
            try Socket.makeInAddr(fromIP4: "192.168.0")
        )
        XCTAssertThrowsError(
            try sockaddr_in.inet(ip4: "::1", port: 80)
        )
    }

    func testINET6_IsCorrectlyDecodedFromStorage() throws {
        let storage = sockaddr_in6
            .inet6(port: 8080)
            .makeStorage()

        XCTAssertEqual(
            try sockaddr_in6.make(from: storage)
                .sin6_port
                .bigEndian,
            8080
        )
    }

    func testINET6_ThrowsInvalidAddress_WhenFamilyIncorrect() throws {
        let storage = sockaddr_un
            .unix(path: "/var")
            .makeStorage()

        XCTAssertThrowsError(
            try sockaddr_in6.make(from: storage),
            of: SocketError.self
        ) {
            XCTAssertEqual($0, .unsupportedAddress)
        }
    }

    func testAddress_DecodesIP6() throws {
        var addr = Socket.makeAddressINET6(port: 5010)
        addr.sin6_addr = try Socket.makeInAddr(fromIP6: "::1")

        XCTAssertEqual(
            try Socket.makeAddress(from: addr.makeStorage()),
            .ip6("::1", port: 5010)
        )
    }

    func testLoopbackAddress_DecodesIP6() throws {
        let loopback = sockaddr_in6.loopback(port: 5060)

        XCTAssertEqual(
            try Socket.makeAddress(from: loopback.makeStorage()),
            .ip6("::1", port: 5060)
        )
    }

    func testInvalidIP6_ThrowsError() {
        XCTAssertThrowsError(
            try Socket.makeInAddr(fromIP6: "192.168.0")
        )
        XCTAssertThrowsError(
            try sockaddr_in6.inet6(ip6: ":10:::::", port: 80)
        )
    }

    func testUnix_IsCorrectlyDecodedFromStorage() throws {
        let storage = sockaddr_un
            .unix(path: "/var")
            .makeStorage()

        var unix = try sockaddr_un.make(from: storage)
        let path = withUnsafePointer(to: &unix.sun_path.0) {
            return String(cString: $0)
        }
        XCTAssertEqual(
            path,
            "/var"
        )
    }

    func testUnix_ThrowsInvalidAddress_WhenFamilyIncorrect() {
        let storage = sockaddr_in6
            .inet6(port: 8080)
            .makeStorage()

        XCTAssertThrowsError(
            try sockaddr_un.make(from: storage),
            of: SocketError.self
        ) {
            XCTAssertEqual($0, .unsupportedAddress)
        }
    }

    func testUnlinkUnix_Throws_WhenPathIsInvalid() {
        XCTAssertThrowsError(
            try Socket.unlink(sockaddr_un()),
            of: SocketError.self
        )
    }

    func testIPX_ThrowsInvalidAddress() {
        var storage = sockaddr_storage()
        storage.ss_family = sa_family_t(AF_IPX)

        XCTAssertThrowsError(
            try Socket.makeAddress(from: storage),
            of: SocketError.self
        ) {
            XCTAssertEqual($0, .unsupportedAddress)
        }
    }

    func testSockaddrInToStorageConversion() throws {
        var addrIn = sockaddr_in()
        addrIn.sin_family = sa_family_t(AF_INET)
        addrIn.sin_port = UInt16(8080).bigEndian
        addrIn.sin_addr = try Socket.makeInAddr(fromIP4: "192.168.1.1")

        let storage = addrIn.makeStorage()

        XCTAssertEqual(storage.ss_family, sa_family_t(AF_INET))
        withUnsafeBytes(of: addrIn) { addrInPtr in
            let storagePtr = addrInPtr.bindMemory(to: sockaddr_storage.self)
            XCTAssertEqual(storagePtr.baseAddress!.pointee.ss_family, sa_family_t(AF_INET))
            let sockaddrInPtr = addrInPtr.bindMemory(to: sockaddr_in.self)
            XCTAssertEqual(sockaddrInPtr.baseAddress!.pointee.sin_port, addrIn.sin_port)
            XCTAssertEqual(sockaddrInPtr.baseAddress!.pointee.sin_addr.s_addr, addrIn.sin_addr.s_addr)
        }
    }

    func testSockaddrIn6ToStorageConversion() throws {
        var addrIn6 = sockaddr_in6()
        addrIn6.sin6_family = sa_family_t(AF_INET6)
        addrIn6.sin6_port = UInt16(9090).bigEndian
        addrIn6.sin6_addr = try Socket.makeInAddr(fromIP6: "fe80::1")

        let storage = addrIn6.makeStorage()

        XCTAssertEqual(storage.ss_family, sa_family_t(AF_INET6))
        XCTAssertEqual(storage.ss_family, addrIn6.sin6_family)

        withUnsafeBytes(of: addrIn6) { addrIn6Ptr in
            let storagePtr = addrIn6Ptr.bindMemory(to: sockaddr_storage.self)
            XCTAssertEqual(storagePtr.baseAddress!.pointee.ss_family, sa_family_t(AF_INET6))
            let sockaddrIn6Ptr = addrIn6Ptr.bindMemory(to: sockaddr_in6.self)
            XCTAssertEqual(sockaddrIn6Ptr.baseAddress!.pointee.sin6_port, addrIn6.sin6_port)
            let addrArray = withUnsafeBytes(of: sockaddrIn6Ptr.baseAddress!.pointee.sin6_addr) {
                Array($0.bindMemory(to: UInt8.self))
            }
            let expectedArray = withUnsafeBytes(of: addrIn6.sin6_addr) {
                Array($0.bindMemory(to: UInt8.self))
            }
            XCTAssertEqual(addrArray, expectedArray)
        }
    }

    func testSockaddrUnToStorageConversion() {
        var addrUn = sockaddr_un()
        addrUn.sun_family = sa_family_t(AF_UNIX)
        let path = "/tmp/socket"
        _ = path.withCString { pathPtr in
            memcpy(&addrUn.sun_path, pathPtr, path.count + 1)
        }

        let storage = addrUn.makeStorage()

        XCTAssertEqual(storage.ss_family, sa_family_t(AF_UNIX))
        let addrUnBytes = withUnsafeBytes(of: addrUn) { Data($0) }
        let storageBytes = withUnsafeBytes(of: storage) { Data($0) }
        let storageSockaddrUnBytes = storageBytes[0..<MemoryLayout<sockaddr_un>.size]
        XCTAssertEqual(addrUnBytes, storageSockaddrUnBytes)
    }

    func testInvalidAddressFamily() {
        var storage = sockaddr_storage()
        storage.ss_family = sa_family_t(AF_APPLETALK) // Invalid for our purpose

        XCTAssertThrowsError(try sockaddr_in.make(from: storage)) { error in
            XCTAssertEqual(error as? SocketError, SocketError.unsupportedAddress)
        }

        XCTAssertThrowsError(try sockaddr_in6.make(from: storage)) { error in
            XCTAssertEqual(error as? SocketError, SocketError.unsupportedAddress)
        }

        XCTAssertThrowsError(try sockaddr_un.make(from: storage)) { error in
            XCTAssertEqual(error as? SocketError, SocketError.unsupportedAddress)
        }
    }

    func testMaximumPathLengthForUnixDomainSocket() {
        var addrUn = sockaddr_un()
        addrUn.sun_family = sa_family_t(AF_UNIX)
        let maxPathLength = MemoryLayout<sockaddr_un>.size - MemoryLayout<sa_family_t>.size - 1
        let maxPath = String(repeating: "a", count: maxPathLength)
        _ = maxPath.withCString { pathPtr in
            memcpy(&addrUn.sun_path, pathPtr, maxPath.count + 1)
        }

        let storage = addrUn.makeStorage()

        XCTAssertEqual(storage.ss_family, sa_family_t(AF_UNIX))
        let addrUnBytes = withUnsafeBytes(of: addrUn) { Data($0) }
        let storageBytes = withUnsafeBytes(of: storage) { Data($0) }
        let storageAddrUnBytes = storageBytes.prefix(MemoryLayout<sockaddr_un>.size)
        XCTAssertEqual(addrUnBytes, storageAddrUnBytes)
    }

    func testMemoryBoundsInMakeStorage() {
        var addrIn = sockaddr_in()
        addrIn.sin_family = sa_family_t(AF_INET)
        
        let storage = addrIn.makeStorage()

        let addrSize = MemoryLayout<sockaddr_in>.size
        let storageSize = MemoryLayout<sockaddr_storage>.size
        XCTAssertLessThanOrEqual(addrSize, storageSize)

        withUnsafeBytes(of: addrIn) { addrInPtr in
            let addrInBytes = addrInPtr.bindMemory(to: UInt8.self).baseAddress!
            withUnsafeBytes(of: storage) { storagePtr in
                let storageBytes = storagePtr.bindMemory(to: UInt8.self).baseAddress!
                for i in 0..<addrSize {
                    XCTAssertEqual(addrInBytes[i], storageBytes[i], "Mismatch at byte \(i)")
                }
            }
        }
    }
}


private extension SocketAddress {

    func makeStorage() -> sockaddr_storage {
        var storage = sockaddr_storage()
        var addr = self
        let addrSize = MemoryLayout<Self>.size
        let storageSize = MemoryLayout<sockaddr_storage>.size

        withUnsafePointer(to: &addr) { addrPtr in
            let addrRawPtr = UnsafeRawPointer(addrPtr)
            withUnsafeMutablePointer(to: &storage) { storagePtr in
                let storageRawPtr = UnsafeMutableRawPointer(storagePtr)
                let copySize = min(addrSize, storageSize)
                storageRawPtr.copyMemory(from: addrRawPtr, byteCount: copySize)
            }
        }
        return storage
    }
}
