//
//  DirectoryHTTPHandlerTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 5/03/2023.
//  Copyright © 2023 Simon Whitty. All rights reserved.
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

final class DirectoryHTTPHandlerTests: XCTestCase {

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

    func testFileURL_isRelative_toServerPath() {
        let handler = DirectoryHTTPHandler(root: URL(fileURLWithPath: "/temp"),
                                           serverPath: "/sub/folder")

        XCTAssertEqual(
            handler.makeFileURL(for: "/sub/folder/fish/chips"),
            URL(fileURLWithPath: "/temp/fish/chips")
        )

        XCTAssertNil(
            handler.makeFileURL(for: "/sub/file/fish/chips")
        )
    }

    func testServerPath_doesNotRequier_leadingSlash() {
        let handler = DirectoryHTTPHandler(root: URL(fileURLWithPath: "/temp"),
                                           serverPath: "sub/folder")

        XCTAssertEqual(
            handler.makeFileURL(for: "/sub/folder/fish/chips"),
            URL(fileURLWithPath: "/temp/fish/chips")
        )
    }

    func testServerPath_doesNotRequire_trailingSlash() {
        let handler = DirectoryHTTPHandler(root: URL(fileURLWithPath: "/temp/file"),
                                           serverPath: "sub")

        XCTAssertEqual(
            handler.makeFileURL(for: "sub/a"),
            URL(fileURLWithPath: "/temp/file/a")
        )
    }

    func testServerPath_IsNotRequired() {
        let handler = DirectoryHTTPHandler(root: URL(fileURLWithPath: "/temp/file"))

        XCTAssertEqual(
            handler.makeFileURL(for: "sub/a"),
            URL(fileURLWithPath: "/temp/file/sub/a")
        )
    }

    func testServerPath_doesNotRequire_canBeEmpty() {
        let handler = DirectoryHTTPHandler(root: URL(fileURLWithPath: "/temp/file"),
                                           serverPath: "")

        XCTAssertEqual(
            handler.makeFileURL(for: "sub/a"),
            URL(fileURLWithPath: "/temp/file/sub/a")
        )
    }
}
