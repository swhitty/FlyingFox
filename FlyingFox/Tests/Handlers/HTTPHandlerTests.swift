//
//  HTTPHandlerTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 22/02/2022.
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

struct HTTPHandlerTests {

    //MARK: - HTTPHandler
    
    @Test
    func unhandledHandler_ThrowsError() async throws {
        let handler: some HTTPHandler = .unhandled()

        await #expect(throws: HTTPUnhandledError.self) {
            try await handler.handleRequest(.make())
        }
    }
    
    //MARK: - RedirectHTTPHandler
    
    @Test
    func redirectHandler_Returns301WithSuppliedLocation() async throws {
        let handler = RedirectHTTPHandler.redirect(to: "http://fish.com/cakes")

        let response = try await handler.handleRequest(.make())
        #expect(response.statusCode == .movedPermanently)
        #expect(response.headers[.location] == "http://fish.com/cakes")
    }

    @Test
    func redirectHandler_ThrowsErrorWhenSuppliedLocationIsInvalid() async {
        let handler = RedirectHTTPHandler(location: "http:// fish cakes")
        await #expect(throws: URLError.self) {
            try await handler.handleRequest(.make())
        }
    }

    //MARK: - FileHTTPHandler
    
    @Test
    func fileHandler_init_path() {
        let expectedURL = URL(string: "file://var/tmp/flyingfox.json")!
        let expectedContentType = "application/json"
        let handler = FileHTTPHandler(path: expectedURL, contentType: expectedContentType)
        #expect(handler.path == expectedURL)
        #expect(handler.contentType == expectedContentType)
    }
    
    @Test
    func fileHandler_init_namedInBundle() throws {
        let handler = FileHTTPHandler(named: "Stubs/fish.json", in: .module)
        let path = try #require(handler.path?.absoluteString)
        #expect(path.hasSuffix("fish.json"))
        #expect(handler.contentType == "application/json")
    }
    
    @Test
    func fileHandler_Returns200WithData() async throws {
        let handler: some HTTPHandler = .file(named: "Stubs/fish.json", in: .module)

        let response = try await handler.handleRequest(.make())
        #expect(response.statusCode == .ok)
        #expect(response.headers[.contentType] == "application/json")
        #expect(
            try await response.bodyString == #"{"fish": "cakes"}"#
        )
    }

    @Test
    func fileHandler_ReturnsSuppliedContentType() async throws {
        let handler = FileHTTPHandler(named: "Stubs/fish.json", in: .module, contentType: "chips")

        let response = try await handler.handleRequest(.make())
        #expect(response.headers[.contentType] == "chips")
    }

    @Test
    func fileHandler_Returns404WhenFileDoesNotExist() async throws {
        let handler = FileHTTPHandler(named: "chips.json", in: .module)

        let response = try await handler.handleRequest(.make())
        #expect(response.statusCode == .notFound)
    }

    @Test
    func fileHandler_Returns404WhenPathDoesNotExist() async throws {
        let handler = FileHTTPHandler(path: URL(fileURLWithPath: "unknown"), contentType: "chips")

        let response = try await handler.handleRequest(.make())
        #expect(response.statusCode == .notFound)
    }

    @Test
    func fileHandler_DetectsCorrectContentType() {
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.json") == "application/json"
        )
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.html") == "text/html"
        )
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.htm") == "text/html"
        )
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.css") == "text/css"
        )
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.js") == "application/javascript"
        )
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.javascript") == "application/javascript"
        )
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.png") == "image/png"
        )
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.jpeg") == "image/jpeg"
        )
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.jpg") == "image/jpeg"
        )
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.pdf") == "application/pdf"
        )
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.svg") == "image/svg+xml"
        )
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.txt") == "text/plain"
        )
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.mp4") == "video/mp4"
        )
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.m4v") == "video/mp4"
        )
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.ico") == "image/x-icon"
        )
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.wasm") == "application/wasm"
        )
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.webp") == "image/webp"
        )
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.jp2") == "image/jp2"
        )
        #expect(
            FileHTTPHandler.makeContentType(for: "fish.somefile") == "application/octet-stream"
        )
    }

    @Test
    func fileHandler_DetectsPartialRange() {
        #expect(
            FileHTTPHandler.makePartialRange(for: [.range: "bytes=1-5"]) == 1...5
        )
        #expect(
            FileHTTPHandler.makePartialRange(for: [.range: "bytes=0-5100"]) == 0...5100
        )
        #expect(
            FileHTTPHandler.makePartialRange(for: [.range: "bytes=0-"], fileSize: 10) == 0...9
        )
        #expect(
            FileHTTPHandler.makePartialRange(for: [.range: "bytes=2-"], fileSize: 10) == 2...9
        )
        #expect(
            FileHTTPHandler.makePartialRange(for: [.range: "bytes = 8 - 10"]) == 8...10
        )
        #expect(
            FileHTTPHandler.makePartialRange(for: [.range: "bytes=5-1"]) == nil
        )
        #expect(
            FileHTTPHandler.makePartialRange(for: [.range: "byte=1-5"]) == nil
        )
        #expect(
            FileHTTPHandler.makePartialRange(for: [.range: ""]) == nil
        )
    }

    @Test
    func fileHandler_ReturnsHeaders_WhenMethodIsHEAD() async throws {
        let handler = FileHTTPHandler(named: "Stubs/fish.json", in: .module)

        let response = try await handler.handleRequest(.make(method: .HEAD))
        #expect(response.statusCode == .ok)
        #expect(response.headers[.contentLength] == "17")
        #expect(response.headers[.acceptRanges] == "bytes")
        try await #expect(response.bodyData.isEmpty)
    }

    @Test
    func fileHandler_Returns206WhenPartialRangeRequested() async throws {
        let handler = FileHTTPHandler(named: "Stubs/fish.json", in: .module)

        let response = try await handler.handleRequest(.make(headers: [.range: "bytes=10-14"]))
        #expect(response.statusCode == .partialContent)
        #expect(response.headers[.contentRange] == "bytes 10-14/17")
        try await #expect(response.bodyString == "cakes")
    }

    //MARK: - ProxyHTTPHandler
    
    @Test(.disabled("pie.dev appears to be down"))
    func proxyHandler_ReturnsResponse() async throws {
        let handler = ProxyHTTPHandler(base: "https://pie.dev", timeout: 2)
        var response = try await handler.handleRequest(.make(method: .GET,
                                                             path: "/status/202",
                                                             query: [.init(name: "hello", value: "world")]))
        #expect(response.statusCode.code == 202)

        response = try await handler.handleRequest(.make(method: .GET, path: "/status/200"))
        #expect(response.statusCode.code == 200)
    }

    @Test
    func proxyHandler_ThrowsErrorWhenBaseIsInvalid() async throws {
        let handler = ProxyHTTPHandler(base: "http:// fish cakes")

        await #expect(throws: URLError.self) {
            try await handler.handleRequest(.make())
        }
    }

    @Test
    func proxyHandler_MakesRequestWithQuery() async throws {
        let handler = ProxyHTTPHandler(base: "fish.com")

        let request = try await handler.makeURLRequest(
            for: .make(path: "/chips/squid",
                       query: [.init(name: "mushy", value: "peas")])
        )

        #expect(
            request.url == URL(string: "fish.com/chips/squid?mushy=peas")
        )
    }

    @Test
    func proxyHandler_MakesRequestWithHeaders() async throws {
        let handler = ProxyHTTPHandler(base: "fish.com")

        let request = try await handler.makeURLRequest(
            for: .make(headers: [.contentType: "json",
                                 HTTPHeader("Fish"): "chips"])
        )

        #expect(
            request.allHTTPHeaderFields == [
                "Content-Type": "json",
                "Fish": "chips"
            ]
        )
    }

    @Test
    func proxyHandler_DoesNotFowardSomeHeaders() async throws {
        let handler = ProxyHTTPHandler.proxy(via: "fish.com")

        let request = try await handler.makeURLRequest(
            for: .make(headers: [.connection: "json",
                                 .host: "fish.com",
                                 .contentLength: "20"])
        )

        #expect(
            request.allHTTPHeaderFields?["Host"] == nil
        )

        #expect(
            request.allHTTPHeaderFields?["Connetion"] == nil
        )

        #expect(
            request.allHTTPHeaderFields?["Content-Length"] == nil
        )
    }

    //MARK: - RoutedHTTPHandler
    
    @Test
    func routedHandler_CatchesUnhandledError() async throws {
        var handler = RoutedHTTPHandler()

        handler.appendRoute("/hello", to: .unhandled())
        handler.appendRoute("/hello") { _ in
            HTTPResponse(statusCode: .ok)
        }

        let response = try await handler.handleRequest(.make(path: "/hello"))
        #expect(response.statusCode == .ok)
    }
}

private extension FileHTTPHandler {
    static func makePartialRange(for headers: [HTTPHeader: String]) -> ClosedRange<Int>? {
        makePartialRange(for: headers, fileSize: 10000)
    }
}
