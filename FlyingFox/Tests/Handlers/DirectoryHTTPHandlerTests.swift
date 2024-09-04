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
import Foundation
import Testing

struct DirectoryHTTPHandlerTests {

    @Test
    func directoryHandler_ReturnsFile() async throws {
        let handler = DirectoryHTTPHandler(bundle: .module, subPath: "Stubs", serverPath: "server/path")

        let response = try await handler.handleRequest(.make(path: "server/path/fish.json"))
        #expect(response.statusCode == .ok)
        #expect(response.headers[.contentType] == "application/json")
        #expect(
            try await response.bodyString == #"{"fish": "cakes"}"#
        )
    }

    @Test
    func directoryHandler_PlainInitialiser_ReturnsFile() async throws {
        let root = try #require(Bundle.module.url(forResource: "Stubs", withExtension: nil))
        let handler = DirectoryHTTPHandler(root: root, serverPath: "server/path")

        let response = try await handler.handleRequest(.make(path: "server/path/fish.json"))
        #expect(response.statusCode == .ok)
        #expect(response.headers[.contentType] == "application/json")
        #expect(
            try await response.bodyString == #"{"fish": "cakes"}"#
        )
    }

    @Test
    func directoryHandler_ReturnsSubDirectoryFile() async throws {
        let handler = DirectoryHTTPHandler.directory(for: .module, subPath: "Stubs", serverPath: "server/path")

        let response = try await handler.handleRequest(.make(path: "server/path/subdir/vinegar.json"))
        #expect(response.statusCode == .ok)
        #expect(response.headers[.contentType] == "application/json")
        #expect(
            try await response.bodyString == #"{"type": "malt"}"#
        )
    }

    @Test
    func directoryHandler_Returns404WhenFileDoesNotExist() async throws {
        let handler = DirectoryHTTPHandler.directory(for: .module, subPath: "Stubs", serverPath: "server/path")

        let response = try await handler.handleRequest(.make())
        #expect(response.statusCode == .notFound)
    }

    @Test
    func directoryHandler_Returns404WhenRequestHasPathButFileDoesNotExist() async throws {
        let handler = DirectoryHTTPHandler(bundle: .module, subPath: "Stubs", serverPath: "server/path")

        let response = try await handler.handleRequest(.make(path: "server/path/subdir/guitars.json"))
        #expect(response.statusCode == .notFound)
    }

    @Test
    func fileURL_isRelative_toServerPath() {
        let handler = DirectoryHTTPHandler(root: URL(fileURLWithPath: "/temp"),
                                           serverPath: "/sub/folder")

        #expect(
            handler.makeFileURL(for: "/sub/folder/fish/chips") == URL(fileURLWithPath: "/temp/fish/chips")
        )

        #expect(
            handler.makeFileURL(for: "/sub/file/fish/chips") == nil
        )
    }

    @Test
    func serverPath_doesNotRequier_leadingSlash() {
        let handler = DirectoryHTTPHandler(root: URL(fileURLWithPath: "/temp"),
                                           serverPath: "sub/folder")

        #expect(
            handler.makeFileURL(for: "/sub/folder/fish/chips") ==  URL(fileURLWithPath: "/temp/fish/chips")
        )
    }

    @Test
    func serverPath_doesNotRequire_trailingSlash() {
        let handler = DirectoryHTTPHandler(root: URL(fileURLWithPath: "/temp/file"),
                                           serverPath: "sub")

        #expect(
            handler.makeFileURL(for: "sub/a") == URL(fileURLWithPath: "/temp/file/a")
        )
    }

    @Test
    func serverPath_IsNotRequired() {
        let handler = DirectoryHTTPHandler(root: URL(fileURLWithPath: "/temp/file"))

        #expect(
            handler.makeFileURL(for: "sub/a") == URL(fileURLWithPath: "/temp/file/sub/a")
        )
    }

    @Test
    func serverPath_doesNotRequire_canBeEmpty() {
        let handler = DirectoryHTTPHandler(root: URL(fileURLWithPath: "/temp/file"),
                                           serverPath: "")

        #expect(
            handler.makeFileURL(for: "sub/a") == URL(fileURLWithPath: "/temp/file/sub/a")
        )
    }
}
