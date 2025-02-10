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
import Testing

struct HTTPDecoderTests {

    @Test
    func GETMethod_IsParsed() async throws {
        let request = try await HTTPDecoder.make().decodeRequestFromString(
            """
            GET /hello HTTP/1.1\r
            \r
            """
        )

        #expect(
            request.method == .GET
        )
    }

    @Test
    func POSTMethod_IsParsed() async throws {
        let request = try await HTTPDecoder.make().decodeRequestFromString(
            """
            POST /hello HTTP/1.1\r
            \r
            """
        )

        #expect(
            request.method == .POST
        )
    }

    @Test
    func CUSTOMMethod_IsParsed() async throws {
        let request = try await HTTPDecoder.make().decodeRequestFromString(
            """
            FISH /hello HTTP/1.1\r
            \r
            """
        )

        #expect(
            request.method == HTTPMethod("FISH")
        )
    }

    @Test
    func path_IsParsed() async throws {
        let request = try await HTTPDecoder.make().decodeRequestFromString(
            """
            GET /hello/world?fish=Chips&with=Mushy%20Peas HTTP/1.1\r
            \r
            """
        )

        #expect(
            request.path == "/hello/world"
        )

        #expect(
            request.query == [
                .init(name: "fish", value: "Chips"),
                .init(name: "with", value: "Mushy Peas")
            ]
        )
    }

    @Test
    func naughtyPath_IsParsed() async throws {
        let request = try await HTTPDecoder.make().decodeRequestFromString(
            """
            GET /../a/b/../c/./d.html?fish=Chips&with=Mushy%20Peas HTTP/1.1\r
            \r
            """
        )

#if canImport(Darwin)
        #expect(
            request.path == "a/c/d.html"
        )
#else
        #expect(
            request.path == "/a/c/d.html"
        )
#endif

        #expect(
            request.query == [
                .init(name: "fish", value: "Chips"),
                .init(name: "with", value: "Mushy Peas")
            ]
        )
    }

    @Test
    func headers_AreParsed() async throws {
        let request = try await HTTPDecoder.make().decodeRequestFromString(
            """
            GET /hello HTTP/1.1\r
            Fish: Chips\r
            Connection: Keep-Alive\r
            content-type: none\r
            \r
            """
        )

        #expect(
            request.headers == [
                HTTPHeader("Fish"): "Chips",
                HTTPHeader("Connection"): "Keep-Alive",
                HTTPHeader("Content-Type"): "none"
            ]
        )
    }

    @Test
    func body_IsNotParsed_WhenContentLength_IsNotProvided() async throws {
        let request = try await HTTPDecoder.make().decodeRequestFromString(
            """
            GET /hello HTTP/1.1\r
            \r
            Hello
            """
        )

        #expect(
            try await request.bodyData == Data()
        )
    }

    @Test
    func body_IsParsed_WhenContentLength_IsProvided() async throws {
        let request = try await HTTPDecoder.make().decodeRequestFromString(
            """
            GET /hello HTTP/1.1\r
            Content-Length: 5\r
            \r
            Hello
            """
        )

        #expect(
            try await request.bodyString == "Hello"
        )
    }

    @Test
    func invalidStatusLine_ThrowsError() async {
        await #expect(throws: HTTPDecoder.Error.self) {
            try await HTTPDecoder.make().decodeRequestFromString(
                """
                GET/hello HTTP/1.1\r
                \r
                """
            )
        }
    }

    @Test
    func body_ThrowsError_WhenSequenceEnds() async throws {
        await #expect(throws: SocketError.self) {
            try await HTTPDecoder.make(sharedRequestReplaySize: 1024).readBody(from: AsyncBufferedEmptySequence(completeImmediately: true), length: "100").get()
        }
        await #expect(throws: SocketError.self) {
            try await HTTPDecoder.make(sharedRequestBufferSize: 1024).readBody(from: AsyncBufferedEmptySequence(completeImmediately: true), length: "100").get()
        }
    }

    @Test
    func bodySequence_CanReplay_WhenSizeIsLessThanMax() async throws {
        let decoder = HTTPDecoder.make(sharedRequestBufferSize: 1, sharedRequestReplaySize: 100)
        let sequence = try await decoder.readBodyFromString("Fish & Chips")
        #expect(sequence.count == 12)
        #expect(sequence.canReplay)
    }

    @Test
    func bodySequence_CanNotReplay_WhenSizeIsGreaterThanMax() async throws {
        let decoder = HTTPDecoder.make(sharedRequestBufferSize: 1, sharedRequestReplaySize: 2)
        let sequence = try await decoder.readBodyFromString("Fish & Chips")
        #expect(sequence.count == 12)
        #expect(!sequence.canReplay)
    }

    @Test
    func invalidPathDecodes() {
        let comps = HTTPDecoder.make().makeComponents(from: nil)
        #expect(comps.path == "")
        #expect(comps.query == [])
    }

    @Test
    func percentEncodedPathDecodes() {
        #expect(
            HTTPDecoder.make().readComponents(from: "/fish%20chips").path == "/fish chips"
        )
        #expect(
            HTTPDecoder.make().readComponents(from: "/ocean/fish%20and%20chips").path == "/ocean/fish and chips"
        )
    }

    @Test
    func percentQueryStringDecodes() {
        #expect(
            HTTPDecoder.make().readComponents(from: "/?fish=%F0%9F%90%9F").query == [
                .init(name: "fish", value: "🐟")
            ]
        )
        #expect(
            HTTPDecoder.make().readComponents(from: "?%F0%9F%90%A1=chips").query == [
                .init(name: "🐡", value: "chips")
            ]
        )
    }

    @Test
    func emptyQueryItem_Decodes() {
        var urlComps = URLComponents()
        urlComps.queryItems = [.init(name: "name", value: nil)]

        #expect(
            HTTPDecoder.make().makeComponents(from: urlComps).query == [
                .init(name: "name", value: "")
            ]
        )
    }

    @Test
    func responseInvalidStatusLine_ThrowsErrorM() async throws {
        await #expect(throws: HTTPDecoder.Error.self) {
            try await HTTPDecoder.make().decodeRequestFromString(
                """
                HTTP/1.1\r
                \r
                """
            )
        }
    }

    @Test
    func responseBody_IsNotParsed_WhenContentLength_IsNotProvided() async throws {
        let response = try await HTTPDecoder.make().decodeResponseFromString(
            """
            HTTP/1.1 202 OK \r
            \r
            Hello
            """
        )

        #expect(
            try await response.bodyData == Data()
        )
    }

    @Test
    func responseBody_IsParsed_WhenContentLength_IsProvided() async throws {
        let response = try await HTTPDecoder.make().decodeResponseFromString(
            """
            HTTP/1.1 202 OK \r
            Content-Length: 5\r
            \r
            Hello
            """
        )

        #expect(
            try await response.bodyString == "Hello"
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
