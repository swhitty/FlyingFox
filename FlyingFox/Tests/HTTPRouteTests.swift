//
//  HTTPRouteTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 13/02/2022.
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

final class HTTPRouteTests: XCTestCase {

    func testMethodAndPathWithQuery() {
        let route = HTTPRoute(method: .PUT, path: "/quick/brown/fox?eats=chips")

        XCTAssertEqual(
            route.method, .caseInsensitive("PUT")
        )
        XCTAssertEqual(
            route.path,
            [.caseInsensitive("quick"), .caseInsensitive("brown"), .caseInsensitive("fox")]
        )
        XCTAssertEqual(
            route.query,
            [.init(name: "eats", value: .caseInsensitive("chips"))]
        )
    }

    func testPathComponents() {
        XCTAssertEqual(
            HTTPRoute("hello/world").path,
            [.caseInsensitive("hello"), .caseInsensitive("world")]
        )

        XCTAssertEqual(
            HTTPRoute("hello/*").path,
            [.caseInsensitive("hello"), .wildcard]
        )
    }

    func testMethod() {
        XCTAssertEqual(
            HTTPRoute("hello/world").method,
            .wildcard
        )

        XCTAssertEqual(
            HTTPRoute("GET hello").method,
            .caseInsensitive("GET")
        )
    }

    func testWildcard_MatchesPath() {
        let route = HTTPRoute("/fish/*")

        XCTAssertTrue(
            route ~= HTTPRequest.make(path: "/fish/chips")
        )

        XCTAssertTrue(
            route ~= HTTPRequest.make(path: "/fish/chips/mushy/peas")
        )

        XCTAssertFalse(
            route ~= HTTPRequest.make(path: "/chips")
        )
    }

    func testMethod_Matches() {
        let route = HTTPRoute("POST /fish/chips")

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .POST, path: "/fish/chips")
        )

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .init(rawValue: "post"), path: "/fish/chips/")
        )

        XCTAssertFalse(
            route ~= HTTPRequest.make(method: .GET, path: "/fish/chips")
        )
    }

    func testWildcardMethod_Matches() {
        let route = HTTPRoute("/fish/chips")

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .POST, path: "/fish/chips")
        )

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .GET, path: "/fish/chips/")
        )

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .init("ANY"), path: "/fish/chips")
        )

        XCTAssertFalse(
            route ~= HTTPRequest.make(method: .GET, path: "/chips/")
        )
    }

    func testWildcardMethod_MatchesRoute() {
        let route = HTTPRoute("GET /mock")

        XCTAssertFalse(
            route ~= HTTPRequest.make(method: HTTPMethod("GET"),
                                      path: "/")
        )

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: HTTPMethod("GET"),
                                      path: "/mock")
        )

        XCTAssertFalse(
            route ~= HTTPRequest.make(method: HTTPMethod("GET"),
                                      path: "/mock/fish")
        )
    }

    func testEmptyWildcard_MatchesAllRoutes() {
        let route = HTTPRoute("*")

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: HTTPMethod("GET"),
                                      path: "/")
        )

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: HTTPMethod("GET"),
                                      path: "/mock")
        )

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: HTTPMethod("GET"),
                                      path: "/mock/fish")
        )
    }

    func testQueryItem_MatchesRoute() {
        let route = HTTPRoute("GET /mock?fish=chips")

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "fish", value: "chips")])
        )

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "cat", value: "dog"),
                                              .init(name: "fish", value: "squid"),
                                              .init(name: "fish", value: "chips")])
        )

        XCTAssertFalse(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "cat", value: "dog"),
                                              .init(name: "fish", value: "squid")])
        )
    }

    func testMultipleQueryItems_MatchesRoute() {
        let route = HTTPRoute("GET /mock?fish=chips&cats=dogs")

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "fish", value: "chips"),
                                              .init(name: "cats", value: "dogs")])
        )

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "cats", value: "dogs"),
                                              .init(name: "fish", value: "chips")])
        )

        XCTAssertFalse(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "fish", value: "chips")])
        )

        XCTAssertFalse(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "cats", value: "dogs")])
        )

        XCTAssertFalse(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "cat", value: "dog"),
                                              .init(name: "fish", value: "squid")])
        )
    }

    func testQueryItemWildcard_MatchesRoute() {
        let route = HTTPRoute("GET /mock?fish=*")

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "fish", value: "chips")])
        )

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "cat", value: "dog"),
                                              .init(name: "fish", value: "squid"),
                                              .init(name: "fish", value: "chips")])
        )

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "cat", value: "dog"),
                                              .init(name: "fish", value: "squid")])
        )
        
         XCTAssertFalse(
             route ~= HTTPRequest.make(method: .GET,
                                       path: "/mock",
                                       query: [.init(name: "cat", value: "dog")])
         )
    }

    func testWildcardPathWithQueryItem_MatchesRoute() {
        let route = HTTPRoute("/mock/*?fish=*")

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock/anemone",
                                      query: [.init(name: "fish", value: "chips")])
        )

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .POST,
                                      path: "/mock/crabs",
                                      query: [.init(name: "fish", value: "shrimp")])
        )

        XCTAssertFalse(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock/anemone")
        )
    }

    func testHeader_MatchesRoute() {
        let route = HTTPRoute("GET /mock", headers: [.contentType: "json"])

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.contentType: "json"])
        )

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.contentEncoding: "xml",
                                                .contentType: "json"])
        )

        XCTAssertFalse(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.contentType: "xml"])
        )
    }

    func testMultipleHeaders_MatchesRoute() {
        let route = HTTPRoute("GET /mock", headers: [.host: "fish",
                                                     .contentType: "json"])

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.host: "fish",
                                                .contentType: "json"])
        )

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.contentType: "json",
                                                .host: "fish"])
        )

        XCTAssertFalse(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.host: "fish"])
        )

        XCTAssertFalse(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.contentType: "json"])
        )

        XCTAssertFalse(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.contentType: "xml",
                                                .host: "fish"])
        )
    }

    func testHeaderWildcard_MatchesRoute() {
        let route = HTTPRoute("GET /mock", headers: [.authorization: "*"])

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.authorization: "Bearer abc"])
        )

        XCTAssertTrue(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.authorization: "Bearer xyz"])
        )

        XCTAssertFalse(
            route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.contentType: "xml"])
        )
    }

#if canImport(Darwin)
    func testBody_MatchesRoute() {
        let route = HTTPRoute("GET /mock", body: .json(where: "food == 'fish'"))

        XCTAssertTrue(
            route ~= HTTPRequest.make(path: "/mock",
                                      body: #"{"age": 45, "food": "fish"}"#.data(using: .utf8)!)
        )

        XCTAssertTrue(
            route ~= HTTPRequest.make(path: "/mock",
                                      body: #"{"food": "fish"}"#.data(using: .utf8)!)
        )

        XCTAssertFalse(
            route ~= HTTPRequest.make(path: "/mock",
                                      body: #"{"age": 45}"#.data(using: .utf8)!)
        )
    }
#endif
}

extension HTTPRouteTests {

    func testDeprecatedTargetMatching() {
        let route = HTTPRoute("GET /mock")

        XCTAssertFalse(
            route ~= "GET /"
        )

        XCTAssertTrue(
            route ~= "GET /mock"
        )

        XCTAssertFalse(
            route ~= "GET /fish/mock"
        )
    }
}
