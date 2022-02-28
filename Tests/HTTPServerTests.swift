//
//  HTTPServerTests.swift
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
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class HTTPServerTests: XCTestCase {

    func testRequests_AreMatchedToHandlers_ViaRoute() async throws {
        let server = HTTPServer(port: 8008)

        await server.appendRoute("/accepted") { _ in
            HTTPResponse.make(statusCode: .accepted)
        }
        await server.appendRoute("/gone") { _ in
            HTTPResponse.make(statusCode: .gone)
        }

        var response = await server.handleRequest(.make(method: .GET, path: "/accepted"))
        XCTAssertEqual(
            response.statusCode,
            .accepted
        )

        response = await server.handleRequest(.make(method: .GET, path: "/gone"))
        XCTAssertEqual(
            response.statusCode,
            .gone
        )
    }

    func testUnmatchedRequests_Return404() async throws {
        let server = HTTPServer(port: 8008)

        let response = await server.handleRequest(.make(method: .GET, path: "/accepted"))
        XCTAssertEqual(
            response.statusCode,
            .notFound
        )
    }

    func testHandlerErrors_Return500() async throws {
        let server = HTTPServer(port: 8008) { _ in
            throw SocketError.disconnected
        }

        let response = await server.handleRequest(.make(method: .GET, path: "/accepted"))
        XCTAssertEqual(
            response.statusCode,
            .internalServerError
        )
    }

    func testHandlerTimeout_Returns500() async throws {
        let server = HTTPServer(port: 8008, timeout: 0.1) { _ in
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return HTTPResponse.make(statusCode: .accepted)
        }

        let response = await server.handleRequest(.make(method: .GET, path: "/accepted"))
        XCTAssertEqual(
            response.statusCode,
            .internalServerError
        )
    }

    func testKeepAlive_IsAddedToResponses() async throws {
        let server = HTTPServer(port: 8008)

        var response = await server.handleRequest(
            .make(method: .GET, path: "/accepted", headers: [.connection: "keep-alive"])
        )
        XCTAssertTrue(
            response.shouldKeepAlive
        )

        response = await server.handleRequest(
            .make(method: .GET, path: "/accepted")
        )
        XCTAssertFalse(
            response.shouldKeepAlive
        )
    }

    func testServer_ReturnsFile_WhenFileHandlerIsMatched() async throws {
        let server = HTTPServer(port: 8009)
        await server.appendRoute("*", to: .file(named: "fish.json", in: .module))
        let task = Task { try await server.start() }

        let request = URLRequest(url: URL(string: "http://localhost:8009")!)
        let (data, _) = try await URLSession.shared.makeData(for: request)

        XCTAssertEqual(
            data,
            #"{"fish": "cakes"}"#.data(using: .utf8)
        )
        task.cancel()
    }

#if canImport(Darwin)
    func testServer_Returns500_WhenHandlerTimesout() async throws {
        let server = HTTPServer(port: 8008, timeout: 0.1)
        await server.appendRoute("*") { _ in
            try await Task.sleep(nanoseconds: 5_000_000_000)
            return .make(statusCode: .ok)
        }
        let task = Task { try await server.start() }

        let request = URLRequest(url: URL(string: "http://localhost:8008")!)
        let (_, response) = try await URLSession.shared.makeData(for: request)

        XCTAssertEqual(
            (response as? HTTPURLResponse)?.statusCode,
            500
        )
        task.cancel()
    }
#endif
}


