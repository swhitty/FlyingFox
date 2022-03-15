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

@testable import FlyingFox
import XCTest
import Foundation

final class SocketAddressTests: XCTestCase {

    func testINET_IsCorrectlyDecodedFromStorage() {
        let storage = sockaddr_in
            .makeINET(port: 8001)
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
            .makeUnix(path: "/var")
            .makeStorage()

        XCTAssertThrowsError(
            try sockaddr_in.make(from: storage),
            of: SocketError.self
        ) {
            XCTAssertEqual($0, .unsupportedAddress)
        }
    }

    func testAddress_DecodesIP4() throws {
        var addr = Socket.makeAddressINET(port: 1080)
        addr.sin_addr = try Socket.makeInAddr(fromIP4: "192.168.0.1")

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
            try Socket.makeInAddr(fromIP4: "::1")
        )
    }

    func testINET6_IsCorrectlyDecodedFromStorage() throws {
        let storage = sockaddr_in6
            .makeINET6(port: 8080)
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
            .makeUnix(path: "/var")
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

    func testInvalidIP6_ThrowsError() {
        XCTAssertThrowsError(
            try Socket.makeInAddr(fromIP6: "192.168.0")
        )
        XCTAssertThrowsError(
            try Socket.makeInAddr(fromIP6: ":10:::::")
        )
    }

    func testUnix_IsCorrectlyDecodedFromStorage() throws {
        let storage = sockaddr_un
            .makeUnix(path: "/var")
            .makeStorage()

        var unix = try sockaddr_un.make(from: storage)
        XCTAssertEqual(
            String(cString: &unix.sun_path.0),
            "/var"
        )
    }

    func testUnix_ThrowsInvalidAddress_WhenFamilyIncorrect() {
        let storage = sockaddr_in6
            .makeINET6(port: 8080)
            .makeStorage()

        XCTAssertThrowsError(
            try sockaddr_un.make(from: storage),
            of: SocketError.self
        ) {
            XCTAssertEqual($0, .unsupportedAddress)
        }
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
}
