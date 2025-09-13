//
//  RedirectHTTPHandlerTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 13/09/2025.
//  Copyright © 2025 Simon Whitty. All rights reserved.
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

struct RedirectHTTPHandlerTests {

    @Test
    func location_is_not_replaced() async throws {
        let handler = RedirectHTTPHandler(location: "http://www.fish.com")

        var response = try await handler.handleRequest(.make(path: "/"))
        #expect(response.statusCode == .movedPermanently)
        #expect(response.headers[.location] == "http://www.fish.com")

        response = try await handler.handleRequest(.make(path: "/chips", query: [.init(name: "fish", value: "true")]))
        #expect(response.headers[.location] == "http://www.fish.com")
    }

    @Test
    func location_statuscode() async throws {
        let handler = RedirectHTTPHandler(location: "http://www.fish.com", statusCode: .temporaryRedirect)

        let response = try await handler.handleRequest(.make(path: "/"))
        #expect(response.statusCode == .temporaryRedirect)
    }

    @Test
    func base_appends_request() async throws {
        let handler: any HTTPHandler = .redirect(via: "http://fish.com")

        var response = try await handler.handleRequest(.make(path: "/chips/shrimp"))
        #expect(response.statusCode == .movedPermanently)
        #expect(response.headers[.location] == "http://fish.com/chips/shrimp")

        response = try await handler.handleRequest(.make(path: "/chips/shrimp", query: [.init(name: "fish", value: "true")]))
        #expect(response.headers[.location] == "http://fish.com/chips/shrimp?fish=true")
    }

    @Test
    func base_removes_serverPath() async throws {
        let handler: any HTTPHandler = .redirect(via: "http://fish.com", serverPath: "chips/shrimp")

        var response = try await handler.handleRequest(.make(path: "/chips/shrimp/1/2", query: [.init(name: "fish", value: "true")]))
        #expect(response.statusCode == .movedPermanently)
        #expect(response.headers[.location] == "http://fish.com/1/2?fish=true")

        response = try await handler.handleRequest(.make(path: "/chips/shrimp/1", query: [.init(name: "fish", value: "true")]))
        #expect(response.headers[.location] == "http://fish.com/1?fish=true")

        await #expect(throws: URLError.self) {
            try await handler.handleRequest(.make(path: "/foo"))
        }
    }

    @Test
    func base_statuscode() async throws {
        let handler = RedirectHTTPHandler(base: "http://fish.com", statusCode: .temporaryRedirect, serverPath: "/chips/shrimp")

        let response = try await handler.handleRequest(.make(path: "/chips/shrimp"))
        #expect(response.statusCode == .temporaryRedirect)
    }
}
