//
//  SocketErrorTests.swift
//  FlyingFox
//
//  Created by Andre Jacobs on 07/03/2022.
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

final class SocketErrorTests: XCTestCase {

    func testSocketError_errorDescription() {
        
        let failedType = "failed"
        let failedErrno: Int32 = 42
        let failedMessage = "failure is an option"
        XCTAssertEqual(
            SocketError.failed(type: failedType, errno: failedErrno, message: failedMessage).errorDescription,
            "SocketError. \(failedType)(\(failedErrno)): \(failedMessage)"
        )
        
        XCTAssertEqual(SocketError.blocked.errorDescription, "SocketError. Blocked")
        XCTAssertEqual(SocketError.disconnected.errorDescription, "SocketError. Disconnected")
        XCTAssertEqual(SocketError.unsupportedAddress.errorDescription, "SocketError. UnsupportedAddress")
    }

    func testSocketError_makeFailed() {
        errno = EIO
        let socketError = SocketError.makeFailed("unit-test")
        switch socketError {
        case let .failed(type: type, errno: socketErrno, message: message):
            XCTAssertEqual(type, "unit-test")
            XCTAssertEqual(socketErrno, EIO)
            XCTAssertEqual(message, "Input/output error")
        default:
            XCTFail()
        }
    }
}
