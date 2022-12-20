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
import XCTest

final class HTTPHandlerTests: XCTestCase {

    //MARK: - HTTPHandler
    
    func testUnhandledHandler_ThrowsError() async {
        let handler: HTTPHandler = .unhandled()

        await AsyncAssertThrowsError(try await handler.handleRequest(.make()), of: HTTPUnhandledError.self)
    }
    
    //MARK: - RedirectHTTPHandler
    
    func testRedirectHandler_Returns301WithSuppliedLocation() async throws {
        let handler = RedirectHTTPHandler.redirect(to: "http://fish.com/cakes")

        let response = try await handler.handleRequest(.make())
        XCTAssertEqual(response.statusCode, .movedPermanently)
        XCTAssertEqual(response.headers[.location], "http://fish.com/cakes")
    }

    func testRedirectHandler_ThrowsErrorWhenSuppliedLocationIsInvalid() async {
        let handler = RedirectHTTPHandler(location: "http:// fish cakes")
        await AsyncAssertThrowsError(try await handler.handleRequest(.make()), of: URLError.self)
    }

    //MARK: - FileHTTPHandler
    
    func testFileHandler_init_path() {
        let expectedURL = URL(string: "file://var/tmp/flyingfox.json")!
        let expectedContentType = "application/json"
        let handler = FileHTTPHandler(path: expectedURL, contentType: expectedContentType)
        XCTAssertEqual(handler.path, expectedURL)
        XCTAssertEqual(handler.contentType, expectedContentType)
    }
    
    func testFileHandler_init_namedInBundle() throws {
        let handler = FileHTTPHandler(named: "Stubs/fish.json", in: .module)
        let path = try XCTUnwrap(handler.path?.absoluteString)
        XCTAssertTrue(path.hasSuffix("fish.json"))
        XCTAssertEqual(handler.contentType, "application/json")
    }
    
    func testFileHandler_Returns200WithData() async throws {
        let handler: HTTPHandler = .file(named: "Stubs/fish.json", in: .module)

        let response = try await handler.handleRequest(.make())
        XCTAssertEqual(response.statusCode, .ok)
        XCTAssertEqual(response.headers[.contentType], "application/json")
        XCTAssertEqual(response.body, #"{"fish": "cakes"}"#.data(using: .utf8))
    }

    func testFileHandler_ReturnsSuppliedContentType() async throws {
        let handler = FileHTTPHandler(named: "Stubs/fish.json", in: .module, contentType: "chips")

        let response = try await handler.handleRequest(.make())
        XCTAssertEqual(response.headers[.contentType], "chips")
    }

    func testFileHandler_Returns404WhenFileDoesNotExist() async throws {
        let handler = FileHTTPHandler(named: "chips.json", in: .module)

        let response = try await handler.handleRequest(.make())
        XCTAssertEqual(response.statusCode, .notFound)
    }

    func testFileHandler_DetectsCorrectContentType() {
        XCTAssertEqual(
            FileHTTPHandler.makeContentType(for: "fish.json"),
            "application/json"
        )
        XCTAssertEqual(
            FileHTTPHandler.makeContentType(for: "fish.html"),
            "text/html"
        )
        XCTAssertEqual(
            FileHTTPHandler.makeContentType(for: "fish.htm"),
            "text/html"
        )
        XCTAssertEqual(
            FileHTTPHandler.makeContentType(for: "fish.css"),
            "text/css"
        )
        XCTAssertEqual(
            FileHTTPHandler.makeContentType(for: "fish.js"),
            "application/javascript"
        )
        XCTAssertEqual(
            FileHTTPHandler.makeContentType(for: "fish.javascript"),
            "application/javascript"
        )
        XCTAssertEqual(
            FileHTTPHandler.makeContentType(for: "fish.png"),
            "image/png"
        )
        XCTAssertEqual(
            FileHTTPHandler.makeContentType(for: "fish.jpeg"),
            "image/jpeg"
        )
        XCTAssertEqual(
            FileHTTPHandler.makeContentType(for: "fish.jpg"),
            "image/jpeg"
        )
        XCTAssertEqual(
            FileHTTPHandler.makeContentType(for: "fish.pdf"),
            "application/pdf"
        )
        XCTAssertEqual(
            FileHTTPHandler.makeContentType(for: "fish.somefile"),
            "application/octet-stream"
        )
    }

    //MARK: - DirectoryHTTPHandler

    func testDirectoryHandler_ReturnsFile() async throws {
        let handler = DirectoryHTTPHandler(bundle: .module, subPath: "Stubs", serverPath: "server/path")

        let response = try await handler.handleRequest(.make(path: "server/path/fish.json"))
        XCTAssertEqual(response.statusCode, .ok)
        XCTAssertEqual(response.headers[.contentType], "application/json")
        XCTAssertEqual(response.body, #"{"fish": "cakes"}"#.data(using: .utf8))
    }

    func testDirectoryHandler_PlainInitialiser_ReturnsFile() async throws {
        let root = try XCTUnwrap(Bundle.module.url(forResource: "Stubs", withExtension: nil))
        let handler = DirectoryHTTPHandler(root: root, serverPath: "server/path")

        let response = try await handler.handleRequest(.make(path: "server/path/fish.json"))
        XCTAssertEqual(response.statusCode, .ok)
        XCTAssertEqual(response.headers[.contentType], "application/json")
        XCTAssertEqual(response.body, #"{"fish": "cakes"}"#.data(using: .utf8))
    }

    func testDirectoryHandler_ReturnsSubDirectoryFile() async throws {
        let handler: HTTPHandler = .directory(for: .module, subPath: "Stubs", serverPath: "server/path")

        let response = try await handler.handleRequest(.make(path: "server/path/subdir/vinegar.json"))
        XCTAssertEqual(response.statusCode, .ok)
        XCTAssertEqual(response.headers[.contentType], "application/json")
        XCTAssertEqual(response.body, #"{"type": "malt"}"#.data(using: .utf8))
    }

    func testDirectoryHandler_Returns404WhenFileDoesNotExist() async throws {
        let handler: HTTPHandler = .directory(for: .module, subPath: "Stubs", serverPath: "server/path")

        let response = try await handler.handleRequest(.make())
        XCTAssertEqual(response.statusCode, .notFound)
    }

    func testDirectoryHandler_Returns404WhenRequestHasPathButFileDoesNotExist() async throws {
        let handler = DirectoryHTTPHandler(bundle: .module, subPath: "Stubs", serverPath: "server/path")

        let response = try await handler.handleRequest(.make(path: "server/path/subdir/guitars.json"))
        XCTAssertEqual(response.statusCode, .notFound)
    }

    //MARK: - ProxyHTTPHandler
    
    func testProxyHandler_ReturnsResponse() async throws {
        let handler = ProxyHTTPHandler(base: "https://pie.dev")
        var response = try await handler.handleRequest(.make(method: .GET,
                                                             path: "/status/202",
                                                             query: [.init(name: "hello", value: "world")]))
        XCTAssertEqual(response.statusCode.code, 202)

        response = try await handler.handleRequest(.make(method: .GET, path: "/status/200"))
        XCTAssertEqual(response.statusCode.code, 200)
    }

    func testProxyHandler_ThrowsErrorWhenBaseIsInvalid() async throws {
        let handler = ProxyHTTPHandler(base: "http:// fish cakes")
        await AsyncAssertThrowsError(
            try await handler.handleRequest(.make()),
            of: URLError.self
        )
    }

    func testProxyHandler_MakesRequestWithQuery() throws {
        let handler = ProxyHTTPHandler(base: "fish.com")

        let request = try handler.makeURLRequest(
            for: .make(path: "/chips/squid",
                       query: [.init(name: "mushy", value: "peas")])
        )

        XCTAssertEqual(
            request.url,
            URL(string: "fish.com/chips/squid?mushy=peas")
        )
    }

    func testProxyHandler_MakesRequestWithHeaders() throws {
        let handler = ProxyHTTPHandler(base: "fish.com")

        let request = try handler.makeURLRequest(
            for: .make(headers: [.contentType: "json",
                                 HTTPHeader("Fish"): "chips"])
        )

        XCTAssertEqual(
            request.allHTTPHeaderFields,
            ["Content-Type": "json",
             "Fish": "chips"]
        )
    }

    func testProxyHandler_DoesNotFowardSomeHeaders() throws {
        let handler = ProxyHTTPHandler.proxy(via: "fish.com")

        let request = try handler.makeURLRequest(
            for: .make(headers: [.connection: "json",
                                 .host: "fish.com",
                                 .contentLength: "20"])
        )

        XCTAssertNil(
            request.allHTTPHeaderFields?["Host"]
        )

        XCTAssertNil(
            request.allHTTPHeaderFields?["Connetion"]
        )

        XCTAssertNil(
            request.allHTTPHeaderFields?["Content-Length"]
        )
    }

    //MARK: - RoutedHTTPHandler
    
    func testRoutedHandler_CatchesUnhandledError() async throws {
        var handler = RoutedHTTPHandler()

        handler.appendRoute("/hello", to: .unhandled())
        handler.appendRoute("/hello") { _ in
            HTTPResponse(statusCode: .ok)
        }

        let response = try await handler.handleRequest(.make(path: "/hello"))
        XCTAssertEqual(response.statusCode, .ok)
    }
}
