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

    @Test func testINET_IsCorrectlyDecodedFromStorage() throws {
        let storage = sockaddr_in
            .inet(port: 8001)
            .makeStorage()

        #expect(
            try sockaddr_in.make(from: storage)
                .sin_port
                .bigEndian == 8001
        )
    }

    @Test func testINET_ThrowsInvalidAddress_WhenFamilyIncorrect() {
        let storage = sockaddr_un
            .unix(path: "/var")
            .makeStorage()

        #expect(throws: SocketError.unsupportedAddress) {
            try sockaddr_in.make(from: storage)
        }
    }

    @Test func testAddress_DecodesIP4() throws {
        let addr = try Socket.makeAddressINET(fromIP4: "192.168.0.1",
                                              port: 1080)

        #expect(
            try Socket.makeAddress(from: addr.makeStorage()) == .ip4("192.168.0.1", port: 1080)
        )
    }

    @Test func testInvalidIP4_ThrowsError() {
        #expect(throws: SocketError.self) {
            try Socket.makeInAddr(fromIP4: "192.168.0")
        }
        #expect(throws: SocketError.self) {
            try sockaddr_in.inet(ip4: "::1", port: 80)
        }
    }

    @Test func testINET6_IsCorrectlyDecodedFromStorage() throws {
        let storage = sockaddr_in6
            .inet6(port: 8080)
            .makeStorage()

        #expect(
            try sockaddr_in6.make(from: storage)
                .sin6_port
                .bigEndian == 8080
        )
    }

    @Test func testINET6_ThrowsInvalidAddress_WhenFamilyIncorrect() throws {
        let storage = sockaddr_un
            .unix(path: "/var")
            .makeStorage()

        #expect(throws: SocketError.unsupportedAddress) {
            try sockaddr_in6.make(from: storage)
        }
    }

    @Test func testAddress_DecodesIP6() throws {
        var addr = Socket.makeAddressINET6(port: 5010)
        addr.sin6_addr = try Socket.makeInAddr(fromIP6: "::1")

        #expect(
            try Socket.makeAddress(from: addr.makeStorage()) == .ip6("::1", port: 5010)
        )
    }

    @Test func testLoopbackAddress_DecodesIP6() throws {
        let loopback = sockaddr_in6.loopback(port: 5060)

        #expect(
            try Socket.makeAddress(from: loopback.makeStorage()) == .ip6("::1", port: 5060)
        )
    }

    @Test func testInvalidIP6_ThrowsError() {
        #expect(throws: SocketError.self) {
            try Socket.makeInAddr(fromIP6: "192.168.0")
        }

        #expect(throws: SocketError.self) {
            try sockaddr_in6.inet6(ip6: ":10:::::", port: 80)
        }
    }

    @Test func testUnix_IsCorrectlyDecodedFromStorage() throws {
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

    @Test func testUnix_ThrowsInvalidAddress_WhenFamilyIncorrect() {
        let storage = sockaddr_in6
            .inet6(port: 8080)
            .makeStorage()

        #expect(throws: SocketError.unsupportedAddress) {
            try sockaddr_un.make(from: storage)
        }
    }

    @Test func testUnlinkUnix_Throws_WhenPathIsInvalid() {
        #expect(throws: SocketError.self) {
            try Socket.unlink(sockaddr_un())
        }
    }

    @Test func testIPX_ThrowsInvalidAddress() {
        var storage = sockaddr_storage()
        storage.ss_family = sa_family_t(AF_IPX)

        #expect(throws: SocketError.unsupportedAddress) {
            try Socket.makeAddress(from: storage)
        }
    }
}
