//
//  HTTPEncoderTests.swift
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

final class HTTPEncoderTests: XCTestCase {

    func testHeaderLines_BeginWithStatusCode() {
        XCTAssertEqual(
            HTTPEncoder
                .makeHeaderLines(from: .make(version: .http2, statusCode: .ok))
                .first,
            "HTTP/2 200 OK"
        )

        XCTAssertEqual(
            HTTPEncoder
                .makeHeaderLines(from: .make(version: HTTPVersion("Fish"),
                                             statusCode: HTTPStatusCode(999, phrase: "Chips")))
                .first,
            "Fish 999 Chips"
        )
    }

    func testHeaderLines_IncludesContentSize() {
        XCTAssertTrue(
            HTTPEncoder.makeHeaderLines(from: .make(body: Data()))
                .contains("Content-Length: 0")
        )

        XCTAssertTrue(
            HTTPEncoder.makeHeaderLines(from: .make(body: Data([0x01])))
                .contains("Content-Length: 1")
        )
        XCTAssertTrue(
            HTTPEncoder.makeHeaderLines(from: .make(body: Data([0x01, 0x02, 0x03])))
                .contains("Content-Length: 3")
        )
    }

    func testHeaderLines_IncludeSuppliedHeaders() {
        let lines = HTTPEncoder
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
            HTTPEncoder
                .makeHeaderLines(from: .make())
                .last,
            "\r\n"
        )

        XCTAssertEqual(
            HTTPEncoder
                .makeHeaderLines(from: .make(headers: [.connection: "keep", .contentType: "none"]))
                .last,
            "\r\n"
        )
    }

    func testEncodesResponseHeader() throws {
        XCTAssertEqual(
            HTTPEncoder.encodeResponseHeader(
                .make(version: .http11,
                      statusCode: .ok,
                      headers: [:],
                      body: "Hello World!".data(using: .utf8)!)
            ),
            """
            HTTP/1.1 200 OK\r
            Content-Length: 12\r
            \r

            """.data(using: .utf8)
        )
    }

#if compiler(>=5.9)
    func testEncodesChunkedResponse() async throws {
        let data = try await HTTPEncoder.encodeResponse(
            .makeChunked(
                version: .http11,
                statusCode: .ok,
                headers: [.transferEncoding: "Fish"],
                body: "Hello World!".data(using: .utf8)!,
                chunkSize: 10
            )
        )

        XCTAssertEqual(
            data,
            """
            HTTP/1.1 200 OK\r
            Transfer-Encoding: Fish, chunked\r
            \r
            0A\r
            Hello Worl\r
            02\r
            d!\r
            0\r
            \r

            """.data(using: .utf8)
        )
    }
#endif

    func testEncodesRequest() async throws {
        await AsyncAssertEqual(
            try await HTTPEncoder.encodeRequest(
                .make(method: .GET,
                      version: .http11,
                      path: "greeting/hello world",
                      query: [],
                      headers: [:],
                      body: "Hello World!".data(using: .utf8)!)
            ),
            """
            GET greeting/hello%20world HTTP/1.1\r
            Content-Length: 12\r
            \r
            Hello World!
            """.data(using: .utf8)
        )
    }

    func testEncodesRequest_WithQuery() async throws {
        await AsyncAssertEqual(
            try await HTTPEncoder.encodeRequest(
                .make(method: .GET,
                      version: .http11,
                      path: "greeting/hello world",
                      query: [.init(name: "fish", value: "chips")],
                      headers: [:],
                      body: "Hello World!".data(using: .utf8)!)
            ),
            """
            GET greeting/hello%20world?fish=chips HTTP/1.1\r
            Content-Length: 12\r
            \r
            Hello World!
            """.data(using: .utf8)
        )
    }
}

private extension HTTPVersion {
    static let http2 = HTTPVersion("HTTP/2")
}

private extension HTTPEncoder {

    static func encodeResponse(_ response: HTTPResponse) async throws -> Data {
        var data = encodeResponseHeader(response)
        switch response.payload {
        case .httpBody(let sequence):
            for try await chunk in sequence {
                data.append(chunk)
            }
        case .webSocket:
            ()
        }
        return data
    }
}
