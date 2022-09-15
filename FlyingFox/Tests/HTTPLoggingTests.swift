//
//  HTTPLoggingTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 23/02/2022.
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
import Foundation
import XCTest

final class HTTPLoggingTests: XCTestCase {

    func testPrintLogger_DefaultCategory() {
        let logger = PrintHTTPLogger.print()

        XCTAssertEqual(
            logger.category,
            "FlyingFox"
        )
    }

    func testPrintLogger_SetsCategory() {
        let logger = PrintHTTPLogger.print(category: "Fish")

        XCTAssertEqual(
            logger.category,
            "Fish"
        )
    }
    
    func testPrintLogger_output() {
        // NOTE: For now this test is only used to verify the output by manual confirmation
        // until Swift.print can be unit-tested or we are able to inject a mock.
        let logger = PrintHTTPLogger.print()
        
        logger.logDebug("alpha")
        logger.logInfo("bravo")
        logger.logWarning("charlie")
        logger.logError("delta")
        logger.logCritical("echo")
    }

    func testListeningLog_INETPort() {
        XCTAssertEqual(
            PrintHTTPLogger.makeListening(on: .ip4("0.0.0.0", port: 1234)),
            "starting server port: 1234"
        )
    }

    func testListeningLog_INET() throws {
        XCTAssertEqual(
            PrintHTTPLogger.makeListening(on: .ip4("8.8.8.8", port: 1234)),
            "starting server 8.8.8.8:1234"
        )
    }

    func testListeningLog_INET6Port() {
        XCTAssertEqual(
            PrintHTTPLogger.makeListening(on: .ip6("::", port: 5678)),
            "starting server port: 5678"
        )
    }

    func testListeningLog_INET6() throws {
        XCTAssertEqual(
            PrintHTTPLogger.makeListening(on: .ip6("::1", port: 1234)),
            "starting server ::1:1234"
        )
    }

    func testListeningLog_UnixPath() {
        XCTAssertEqual(
            PrintHTTPLogger.makeListening(on: .unix("/var/fox/xyz")),
            "starting server path: /var/fox/xyz"
        )
    }

    func testListeningLog_Invalid() {
        XCTAssertEqual(
            PrintHTTPLogger.makeListening(on: nil),
            "starting server"
        )
    }
}
