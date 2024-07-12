//
//  RoutedHTTPHandler.swift
//  FlyingFox
//
//  Created by Simon Whitty on 12/04/2024.
//  Copyright © 2024 Simon Whitty. All rights reserved.
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

import FlyingFox
import XCTest

final class RoutedHTTPHandlerTests: XCTestCase {

    func testRoutes_CanBeReplaced() async throws {
        // given
        var handler = RoutedHTTPHandler()

        // when
        handler.insertRoute("GET /fish", at: 0, to: MockHandler())
        handler.insertRoute("GET /chips", at: 0) { _ in throw HTTPUnhandledError() }

        // then
        XCTAssertEqual(
            handler.map(\.route.stringValue),
            ["GET /chips", "GET /fish"]
        )

        // when
        handler[1] = ("POST /shrimp", MockHandler())

        // then
        XCTAssertEqual(
            handler.map(\.route.stringValue),
            ["GET /chips", "POST /shrimp"]
        )

        // when
        handler.replaceSubrange(0..., with: [(HTTPRoute("POST /fish"), MockHandler())])

        // then
        XCTAssertEqual(
            handler.map(\.route.stringValue),
            ["POST /fish"]
        )

        // when
        handler.removeAll()

        // then
        XCTAssertTrue(
            handler.isEmpty
        )
    }

    func testPathParameters() async throws {
        // given
        var handler = RoutedHTTPHandler()

        handler.appendRoute("GET /:id/hello/:food") { request in
            let body = [request.pathParameter(for: "id"), request.pathParameter(for: "food")]
                .compactMap { $0 }
                .joined(separator: " ")
            return HTTPResponse(
                statusCode: .ok,
                body: body.data(using: .utf8)!
            )
        }

        // when then
        await AsyncAssertEqual(
            try await handler.handleRequest(.make(path: "/10/hello/fish")).bodyData,
            "10 fish".data(using: .utf8)
        )

        await AsyncAssertEqual(
            try await handler.handleRequest(.make(path: "/450/hello/chips")).bodyData,
            "450 chips".data(using: .utf8)
        )
    }

#if compiler(>=5.9)
    func testParameterPackRoute() async throws {
        // given
        var handler = RoutedHTTPHandler()

        handler.appendRoute("GET /:id/hello/:food") { (id: Int, food: String) -> HTTPResponse in
            HTTPResponse(
                statusCode: .ok,
                body: "\(id * 2) \(food)".data(using: .utf8)!
            )
        }

        // when then
        await AsyncAssertEqual(
            try await handler.handleRequest(.make(path: "/10/hello/fish")).bodyData,
            "20 fish".data(using: .utf8)
        )

        await AsyncAssertEqual(
            try await handler.handleRequest(.make(path: "/450/hello/shrimp")).bodyData,
            "900 shrimp".data(using: .utf8)
        )
    }
#endif
}

private struct MockHandler: HTTPHandler {
    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        throw HTTPUnhandledError()
    }
}

private extension HTTPRoute {

    var stringValue: String {
        let methods = methods.map(\.rawValue).sorted().joined(separator: ",")
        let path = path.map(\.description).joined(separator: "/")
        return methods + " /" + path
    }
}
