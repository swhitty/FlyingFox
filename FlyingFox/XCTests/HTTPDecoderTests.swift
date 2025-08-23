//
//  HTTPDecoderTests.swift
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
import FlyingSocks
import Foundation
import XCTest

final class HTTPDecoderTests: XCTestCase {

    func testGETMethod_IsParsed() async throws {
        let request = try await HTTPDecoder.make().decodeRequestFromString(
            """
            GET /hello HTTP/1.1\r
            \r
            """
        )

        XCTAssertEqual(
            request.method,
            .GET
        )
    }

    func testPOSTMethod_IsParsed() async throws {
        let request = try await HTTPDecoder.make().decodeRequestFromString(
            """
            POST /hello HTTP/1.1\r
            \r
            """
        )

        XCTAssertEqual(
            request.method,
            .POST
        )
    }

    func testCUSTOMMethod_IsParsed() async throws {
        let request = try await HTTPDecoder.make().decodeRequestFromString(
            """
            FISH /hello HTTP/1.1\r
            \r
            """
        )

        XCTAssertEqual(
            request.method,
            HTTPMethod("FISH")
        )
    }

    func testPath_IsParsed() async throws {
        let request = try await HTTPDecoder.make().decodeRequestFromString(
            """
            GET /hello/world?fish=Chips&with=Mushy%20Peas HTTP/1.1\r
            \r
            """
        )

        XCTAssertEqual(
            request.path,
            "/hello/world"
        )

        XCTAssertEqual(
            request.query,
            [.init(name: "fish", value: "Chips"),
             .init(name: "with", value: "Mushy Peas")]
        )
    }

    func testNaughtyPath_IsParsed() async throws {
        let request = try await HTTPDecoder.make().decodeRequestFromString(
            """
            GET /../a/b/../c/./d.html?fish=Chips&with=Mushy%20Peas HTTP/1.1\r
            \r
            """
        )

        XCTAssertEqual(
            request.path,
            "/a/c/d.html"
        )

        XCTAssertEqual(
            request.query,
            [.init(name: "fish", value: "Chips"),
             .init(name: "with", value: "Mushy Peas")]
        )
    }

    func testHeaders_AreParsed() async throws {
        let request = try await HTTPDecoder.make().decodeRequestFromString(
            """
            GET /hello HTTP/1.1\r
            Fish: Chips\r
            Connection: Keep-Alive\r
            content-type: none\r
            \r
            """
        )

        XCTAssertEqual(
            request.headers,
            [HTTPHeader("Fish"): "Chips",
             HTTPHeader("Connection"): "Keep-Alive",
             HTTPHeader("Content-Type"): "none"]
        )
    }

    func testBody_IsNotParsed_WhenContentLength_IsNotProvided() async throws {
        let request = try await HTTPDecoder.make().decodeRequestFromString(
            """
            GET /hello HTTP/1.1\r
            \r
            Hello
            """
        )

        await AsyncAssertEqual(
            try await request.bodyData,
            Data()
        )
    }

    func testBody_IsParsed_WhenContentLength_IsProvided() async throws {
        let request = try await HTTPDecoder.make().decodeRequestFromString(
            """
            GET /hello HTTP/1.1\r
            Content-Length: 5\r
            \r
            Hello
            """
        )

        await AsyncAssertEqual(
            try await request.bodyData,
            "Hello".data(using: .utf8)
        )
    }

    func testInvalidStatusLine_ThrowsErrorM() async throws {
        do {
            _ = try await HTTPDecoder.make().decodeRequestFromString(
                """
                GET/hello HTTP/1.1\r
                \r
                """
            )
            XCTFail("Expected Error")
        } catch {
            XCTAssertTrue(error is HTTPDecoder.Error)
        }
    }

    func testBody_ThrowsError_WhenSequenceEnds() async throws {
        await AsyncAssertThrowsError(
            _ = try await HTTPDecoder.make(sharedRequestReplaySize: 1024).readBody(from: AsyncBufferedEmptySequence(completeImmediately: true), length: "100").get(),
            of: SocketError.self
        )
        await AsyncAssertThrowsError(
            _ = try await HTTPDecoder.make(sharedRequestReplaySize: 1024).readBody(from: AsyncBufferedEmptySequence(completeImmediately: true), length: "100").get(),
            of: SocketError.self
        )
    }

    func testBodySequence_CanReplay_WhenSizeIsLessThanMax() async throws {
        let decoder = HTTPDecoder.make(sharedRequestBufferSize: 1, sharedRequestReplaySize: 100)
        let sequence = try await decoder.readBodyFromString("Fish & Chips")
        XCTAssertEqual(sequence.count, 12)
        XCTAssertTrue(sequence.canReplay)
    }

    func testBodySequence_CanNotReplay_WhenSizeIsGreaterThanMax() async throws {
        let decoder = HTTPDecoder.make(sharedRequestBufferSize: 1, sharedRequestReplaySize: 2)
        let sequence = try await decoder.readBodyFromString("Fish & Chips")
        XCTAssertEqual(sequence.count, 12)
        XCTAssertFalse(sequence.canReplay)
    }

    func testInvalidPathDecodes() {
        let comps = HTTPDecoder.make().makeComponents(from: nil)
        XCTAssertEqual(
            comps.path, ""
        )
        XCTAssertEqual(
            comps.query, []
        )
    }

    func testPercentEncodedPathDecodes() {
        XCTAssertEqual(
            HTTPDecoder.make().readComponents(from: "/fish%20chips").path,
            "/fish chips"
        )
        XCTAssertEqual(
            HTTPDecoder.make().readComponents(from: "/ocean/fish%20and%20chips").path,
            "/ocean/fish and chips"
        )
    }

    func testPercentQueryStringDecodes() {
        XCTAssertEqual(
            HTTPDecoder.make().readComponents(from: "/?fish=%F0%9F%90%9F").query,
            [.init(name: "fish", value: "🐟")]
        )
        XCTAssertEqual(
            HTTPDecoder.make().readComponents(from: "?%F0%9F%90%A1=chips").query,
            [.init(name: "🐡", value: "chips")]
        )
    }

    func testEmptyQueryItem_Decodes() {
        var urlComps = URLComponents()
        urlComps.queryItems = [.init(name: "name", value: nil)]

        XCTAssertEqual(
            HTTPDecoder.make().makeComponents(from: urlComps).query,
            [.init(name: "name", value: "")]
        )
    }

    func testResponseInvalidStatusLine_ThrowsErrorM() async throws {
        do {
            _ = try await HTTPDecoder.make().decodeResponseFromString(
                """
                HTTP/1.1\r
                \r
                """
            )
            XCTFail("Expected Error")
        } catch {
            XCTAssertTrue(error is HTTPDecoder.Error)
        }
    }

    func testResponseBody_IsNotParsed_WhenContentLength_IsNotProvided() async throws {
        let response = try await HTTPDecoder.make().decodeResponseFromString(
            """
            HTTP/1.1 202 OK \r
            \r
            Hello
            """
        )

        await AsyncAssertEqual(
            try await response.bodyData,
            Data()
        )
    }

    func testResponseBody_IsParsed_WhenContentLength_IsProvided() async throws {
        let response = try await HTTPDecoder.make().decodeResponseFromString(
            """
            HTTP/1.1 202 OK \r
            Content-Length: 5\r
            \r
            Hello
            """
        )

        await AsyncAssertEqual(
            try await response.bodyData,
            "Hello".data(using: .utf8)
        )
    }
}

private extension HTTPDecoder {

    func decodeRequestFromString(_ string: String) async throws -> HTTPRequest {
        try await decodeRequest(from: ConsumingAsyncSequence(string.data(using: .utf8)!))
    }

    func decodeResponseFromString(_ string: String) async throws -> HTTPResponse {
        try await decodeResponse(from: ConsumingAsyncSequence(string.data(using: .utf8)!))
    }

    func readBodyFromString(_ string: String) async throws -> HTTPBodySequence {
        let data = string.data(using: .utf8)!
        return try await readBody(
            from: ConsumingAsyncSequence(data),
            length: "\(data.count)"
        )
    }
}
