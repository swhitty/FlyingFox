//
//  HTTPResponseEncoderTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 17/02/2022.
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

final class HTTPResponseEncoderTests: XCTestCase {

    func testHeaderLines_BeginWithStatusCode() {
        XCTAssertEqual(
            HTTPResponseEncoder
                .makeHeaderLines(from: .make(version: .http2, statusCode: .ok))
                .first,
            "HTTP/2 200 OK"
        )

        XCTAssertEqual(
            HTTPResponseEncoder
                .makeHeaderLines(from: .make(version: HTTPVersion(rawValue: "Fish"),
                                             statusCode: HTTPStatusCode(999, phrase: "Chips")))
                .first,
            "Fish 999 Chips"
        )
    }

    func testHeaderLines_IncludesContentSize() {
        XCTAssertTrue(
            HTTPResponseEncoder.makeHeaderLines(from: .make(body: Data()))
                .contains("Content-Length: 0")
        )

        XCTAssertTrue(
            HTTPResponseEncoder.makeHeaderLines(from: .make(body: Data([0x01])))
                .contains("Content-Length: 1")
        )
        XCTAssertTrue(
            HTTPResponseEncoder.makeHeaderLines(from: .make(body: Data([0x01, 0x02, 0x03])))
                .contains("Content-Length: 3")
        )
    }

    func testHeaderLines_IncludeSuppliedHeaders() {

        let lines = HTTPResponseEncoder
            .makeHeaderLines(from: .make(headers: [
                .connection: "keep",
                .location: "Swan Hill",
                .init(rawValue: "Flying"): "Fox"
            ]))

        XCTAssertTrue(
            lines.contains("Connection: keep")
        )

        XCTAssertTrue(
            lines.contains("Location: Swan Hill")
        )

        XCTAssertTrue(
            lines.contains("Flying: Fox")
        )
    }

    func testHeaderLines_EndWithCarriageReturnLineFeed() {
        XCTAssertEqual(
            HTTPResponseEncoder
                .makeHeaderLines(from: .make())
                .last,
            "\r\n"
        )

        XCTAssertEqual(
            HTTPResponseEncoder
                .makeHeaderLines(from: .make(headers: [.connection: "keep", .contentType: "none"]))
                .last,
            "\r\n"
        )
    }
}

private extension HTTPVersion {
    static let http2 = HTTPVersion(rawValue: "HTTP/2")
}
