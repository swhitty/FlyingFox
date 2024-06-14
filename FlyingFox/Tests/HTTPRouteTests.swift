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
            route.methods, [.PUT]
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

    func testPercentEncodedPathComponents() {
        XCTAssertEqual(
            HTTPRoute("GET /hello world").path,
            [.caseInsensitive("hello world")]
        )

        XCTAssertEqual(
            HTTPRoute("/hello%20world").path,
            [.caseInsensitive("hello world")]
        )

        XCTAssertEqual(
            HTTPRoute("🐡/*").path,
            [.caseInsensitive("🐡"), .wildcard]
        )

        XCTAssertEqual(
            HTTPRoute("%F0%9F%90%A1/*").path,
            [.caseInsensitive("🐡"), .wildcard]
        )
    }

    func testPercentEncodedQueryItems() {
        XCTAssertEqual(
            HTTPRoute("/?fish=%F0%9F%90%9F").query,
            [.init(name: "fish", value: .caseInsensitive("🐟"))]
        )
        XCTAssertEqual(
            HTTPRoute("/?%F0%9F%90%A1=chips").query,
            [.init(name: "🐡", value: .caseInsensitive("chips"))]
        )
    }

    func testMethod() {
        XCTAssertEqual(
            HTTPRoute("hello/world").methods,
            HTTPMethod.allMethods
        )

        XCTAssertTrue(
            HTTPRoute("GET hello").methods.contains(.GET)
        )

        XCTAssertEqual(
            HTTPRoute("GET,POST hello").methods,
            [.GET, .POST]
        )

        XCTAssertFalse(
            HTTPRoute("GET,POST hello").methods.contains(.PUT)
        )
    }

    func testWildcard_MatchesPath() async {
        let route = HTTPRoute("/fish/*")

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(path: "/fish/chips")
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(path: "/fish/chips/mushy/peas")
        )

        await AsyncAssertFalse(
            await route ~= HTTPRequest.make(path: "/chips")
        )
    }

    func testMethod_Matches() async {
        let route = HTTPRoute("POST /fish/chips")

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .POST, path: "/fish/chips")
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .init(rawValue: "post"), path: "/fish/chips/")
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: "post", path: "/fish/chips/")
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: "POST", path: "/fish/chips/")
        )

        await AsyncAssertFalse(
            await route ~= HTTPRequest.make(method: .GET, path: "/fish/chips")
        )
    }

    func testWildcardMethod_Matches() async {
        let route = HTTPRoute("/fish/chips")

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .POST, path: "/fish/chips")
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .GET, path: "/fish/chips/")
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .init("GET"), path: "/fish/chips")
        )

        await AsyncAssertFalse(
            await route ~= HTTPRequest.make(method: .GET, path: "/chips/")
        )
    }

    func testWildcardMethod_MatchesRoute() async {
        let route = HTTPRoute("GET /mock")

        await AsyncAssertFalse(
            await route ~= HTTPRequest.make(method: HTTPMethod("GET"),
                                      path: "/")
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: HTTPMethod("GET"),
                                      path: "/mock")
        )

        await AsyncAssertFalse(
            await route ~= HTTPRequest.make(method: HTTPMethod("GET"),
                                      path: "/mock/fish")
        )
    }

    func testEmptyWildcard_MatchesAllRoutes() async {
        let route = HTTPRoute("*")

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: HTTPMethod("GET"),
                                      path: "/")
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: HTTPMethod("GET"),
                                      path: "/mock")
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: HTTPMethod("GET"),
                                      path: "/mock/fish")
        )
    }

    func testQueryItem_MatchesRoute() async {
        let route = HTTPRoute("GET /mock?fish=chips")

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "fish", value: "chips")])
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "cat", value: "dog"),
                                              .init(name: "fish", value: "squid"),
                                              .init(name: "fish", value: "chips")])
        )

        await AsyncAssertFalse(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "cat", value: "dog"),
                                              .init(name: "fish", value: "squid")])
        )
    }

    func testMultipleQueryItems_MatchesRoute() async {
        let route = HTTPRoute("GET /mock?fish=chips&cats=dogs")

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "fish", value: "chips"),
                                              .init(name: "cats", value: "dogs")])
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "cats", value: "dogs"),
                                              .init(name: "fish", value: "chips")])
        )

        await AsyncAssertFalse(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "fish", value: "chips")])
        )

        await AsyncAssertFalse(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "cats", value: "dogs")])
        )

        await AsyncAssertFalse(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "cat", value: "dog"),
                                              .init(name: "fish", value: "squid")])
        )
    }

    func testQueryItemWildcard_MatchesRoute() async {
        let route = HTTPRoute("GET /mock?fish=*")

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "fish", value: "chips")])
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "cat", value: "dog"),
                                              .init(name: "fish", value: "squid"),
                                              .init(name: "fish", value: "chips")])
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "cat", value: "dog"),
                                              .init(name: "fish", value: "squid")])
        )
        
        await AsyncAssertFalse(
             await route ~= HTTPRequest.make(method: .GET,
                                       path: "/mock",
                                       query: [.init(name: "cat", value: "dog")])
         )
    }

    func testWildcardPathWithQueryItem_MatchesRoute() async {
        let route = HTTPRoute("/mock/*?fish=*")

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock/anemone",
                                      query: [.init(name: "fish", value: "chips")])
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .POST,
                                      path: "/mock/crabs",
                                      query: [.init(name: "fish", value: "shrimp")])
        )

        await AsyncAssertFalse(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock/anemone")
        )
    }

    func testHeader_MatchesRoute() async {
        let route = HTTPRoute("GET /mock", headers: [.contentType: "json"])

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.contentType: "json"])
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.contentType: "xml, json"])
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.contentEncoding: "xml",
                                                .contentType: "json"])
        )

        await AsyncAssertFalse(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.contentType: "xml"])
        )
    }

    func testMultipleHeaders_MatchesRoute() async {
        let route = HTTPRoute("GET /mock", headers: [.host: "fish",
                                                     .contentType: "json"])

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.host: "fish",
                                                .contentType: "json"])
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.contentType: "json",
                                                .host: "fish"])
        )

        await AsyncAssertFalse(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.host: "fish"])
        )

        await AsyncAssertFalse(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.contentType: "json"])
        )

        await AsyncAssertFalse(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.contentType: "xml",
                                                .host: "fish"])
        )
    }

    func testHeaderWildcard_MatchesRoute() async {
        let route = HTTPRoute("GET /mock", headers: [.authorization: "*"])

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.authorization: "Bearer abc"])
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.authorization: "Bearer xyz"])
        )

        await AsyncAssertFalse(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.contentType: "xml"])
        )
    }

#if canImport(Darwin)
    func testBody_MatchesRoute() async {
        let route = HTTPRoute("GET /mock", body: .json(where: "food == 'fish'"))

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(path: "/mock",
                                      body: #"{"age": 45, "food": "fish"}"#.data(using: .utf8)!)
        )

        await AsyncAssertTrue(
            await route ~= HTTPRequest.make(path: "/mock",
                                      body: #"{"food": "fish"}"#.data(using: .utf8)!)
        )

        await AsyncAssertFalse(
            await route ~= HTTPRequest.make(path: "/mock",
                                      body: #"{"age": 45}"#.data(using: .utf8)!)
        )
    }
#endif

    func testDeprecated_Method() {
        XCTAssertEqual(HTTPRoute("/fish/*").method, .wildcard)
        XCTAssertEqual(HTTPRoute("GET /fish/*").method, .caseInsensitive("GET"))
        XCTAssertEqual(HTTPRoute("PUT /fish/*").method, .caseInsensitive("PUT"))
        XCTAssertEqual(HTTPRoute("GET,PUT /fish/*").method, .caseInsensitive("GET"))
    }

    func testPathParameters() async {
        let route = HTTPRoute("GET /mock/:id")
        let parameters = route.pathParameters
        XCTAssertEqual(parameters.count, 1)
        XCTAssertEqual(parameters["id"], 1) // Position 1 in the components array

        let route2 = HTTPRoute("GET /mock/:id/:bloop/hello/guys/:zonk")
        let parameters2 = route2.pathParameters
        XCTAssertEqual(parameters2.count, 3)
        XCTAssertEqual(parameters2["id"], 1)
        XCTAssertEqual(parameters2["bloop"], 2)
        XCTAssertEqual(parameters2["zonk"], 5)

        let route3 = HTTPRoute("GET /mock/:id/not:bloop/hello/guys/:zonk")
        let parameters3 = route3.pathParameters
        XCTAssertEqual(parameters3.count, 2)
        XCTAssertEqual(parameters3["id"], 1)
        XCTAssertNil(parameters3["bloop"])
        XCTAssertEqual(parameters2["zonk"], 5)
    }
}
