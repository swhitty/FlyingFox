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
import Testing

struct HTTPEncoderTests {

    @Test
    func headerLines_BeginWithStatusCode() {
        #expect(
            HTTPEncoder
                .makeHeaderLines(from: .make(version: .http2, statusCode: .ok))
                .first ==  "HTTP/2 200 OK"
        )

        #expect(
            HTTPEncoder
                .makeHeaderLines(from: .make(version: HTTPVersion("Fish"),
                                             statusCode: HTTPStatusCode(999, phrase: "Chips")))
                .first == "Fish 999 Chips"
        )
    }

    @Test
    func headerLines_IncludesContentSize() {
        #expect(
            HTTPEncoder.makeHeaderLines(from: .make(body: Data()))
                .contains("Content-Length: 0")
        )

        #expect(
            HTTPEncoder.makeHeaderLines(from: .make(body: Data([0x01])))
                .contains("Content-Length: 1")
        )
        #expect(
            HTTPEncoder.makeHeaderLines(from: .make(body: Data([0x01, 0x02, 0x03])))
                .contains("Content-Length: 3")
        )
    }

    @Test
    func headerLines_IncludeSuppliedHeaders() {
        let lines = HTTPEncoder
            .makeHeaderLines(from: .make(headers: [
                .connection: "keep",
                .location: "Swan Hill",
                .init(rawValue: "Flying"): "Fox"
            ]))

        #expect(
            lines.contains("Connection: keep")
        )

        #expect(
            lines.contains("Location: Swan Hill")
        )

        #expect(
            lines.contains("Flying: Fox")
        )
    }

    @Test
    func headerLines_EndWithCarriageReturnLineFeed() {
        #expect(
            HTTPEncoder
                .makeHeaderLines(from: .make())
                .last == "\r\n"
        )

        #expect(
            HTTPEncoder
                .makeHeaderLines(from: .make(headers: [.connection: "keep", .contentType: "none"]))
                .last == "\r\n"
        )
    }

    @Test
    func encodesResponseHeader() throws {
        #expect(
            HTTPEncoder.encodeResponseHeader(
                .make(version: .http11,
                      statusCode: .ok,
                      headers: [:],
                      body: "Hello World!".data(using: .utf8)!)
            ) == """
            HTTP/1.1 200 OK\r
            Content-Length: 12\r
            \r

            """.data(using: .utf8)
        )
    }

    @Test
    func encodesChunkedResponse() async throws {
        let data = try await HTTPEncoder.encodeResponse(
            .makeChunked(
                version: .http11,
                statusCode: .ok,
                headers: [.transferEncoding: "Fish"],
                body: "Hello World!".data(using: .utf8)!,
                chunkSize: 10
            )
        )

        #expect(
            data == """
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

    @Test
    func encodesMultipleCookiesHeaders() async throws {
        var headers = HTTPHeaders()
        headers.addValue("Fish", for: .setCookie)
        headers.addValue("Chips", for: .setCookie)
        let data = try await HTTPEncoder.encodeResponse(
            .make(headers: headers, body: Data())
        )

        print(String(data: data, encoding: .utf8)!)
        #expect(
            String(data: data, encoding: .utf8) == """
            HTTP/1.1 200 OK\r
            Content-Length: 0\r
            Set-Cookie: Fish\r
            Set-Cookie: Chips\r
            \r

            """
        )
    }

    @Test
    func encodesRequest() async throws {
        #expect(
            try await HTTPEncoder.encodeRequest(
                .make(method: .GET,
                      version: .http11,
                      path: "greeting/hello world",
                      query: [],
                      headers: [:],
                      body: "Hello World!".data(using: .utf8)!)
            ) == """
            GET greeting/hello%20world HTTP/1.1\r
            Content-Length: 12\r
            \r
            Hello World!
            """.data(using: .utf8)
        )
    }

    @Test
    func encodesRequest_WithQuery() async throws {
        #expect(
            try await HTTPEncoder.encodeRequest(
                .make(method: .GET,
                      version: .http11,
                      path: "greeting/hello world",
                      query: [.init(name: "fish", value: "chips")],
                      headers: [:],
                      body: "Hello World!".data(using: .utf8)!)
            ) == """
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
