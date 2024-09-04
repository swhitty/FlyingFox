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
import Foundation
import Testing

struct HTTPRouteTests {

    @Test
    func methodAndPathWithQuery() {
        let route = HTTPRoute(method: .PUT, path: "/quick/brown/fox?eats=chips")

        #expect(
            route.methods == [.PUT]
        )
        #expect(
            route.path == [
                .caseInsensitive("quick"),
                .caseInsensitive("brown"),
                .caseInsensitive("fox")
            ]
        )
        #expect(
            route.query == [
                .init(name: "eats", value: .caseInsensitive("chips"))
            ]
        )
    }

    @Test
    func pathComponents() {
        #expect(
            HTTPRoute("hello/world").path == [
                .caseInsensitive("hello"), .caseInsensitive("world")
            ]
        )

        #expect(
            HTTPRoute("hello/*").path == [
                .caseInsensitive("hello"), .wildcard
            ]
        )
    }

    @Test
    func percentEncodedPathComponents() {
        #expect(
            HTTPRoute("GET /hello world").path == [
                .caseInsensitive("hello world")
            ]
        )

        #expect(
            HTTPRoute("/hello%20world").path == [
                .caseInsensitive("hello world")
            ]
        )

        #expect(
            HTTPRoute("🐡/*").path == [
                .caseInsensitive("🐡"), .wildcard
            ]
        )

        #expect(
            HTTPRoute("%F0%9F%90%A1/*").path == [
                .caseInsensitive("🐡"), .wildcard
            ]
        )
    }

    @Test
    func percentEncodedQueryItems() {
        #expect(
            HTTPRoute("/?fish=%F0%9F%90%9F").query == [
                .init(name: "fish", value: .caseInsensitive("🐟"))
            ]
        )
        #expect(
            HTTPRoute("/?%F0%9F%90%A1=chips").query == [
                .init(name: "🐡", value: .caseInsensitive("chips"))
            ]
        )
    }

    @Test
    func methods() {
        #expect(
            HTTPRoute("hello/world").methods == HTTPMethod.allMethods
        )

        #expect(
            HTTPRoute("GET hello").methods.contains(.GET)
        )

        #expect(
            HTTPRoute("GET,POST hello").methods == [.GET, .POST]
        )

        #expect(
            HTTPRoute("GET,POST hello").methods.contains(.PUT) == false
        )
    }

    @Test
    func wildcard_MatchesPath() async {
        let route = HTTPRoute("/fish/*")

        #expect(
            await route ~= HTTPRequest.make(path: "/fish/chips")
        )

        #expect(
            await route ~= HTTPRequest.make(path: "/fish/chips/mushy/peas")
        )

        #expect(
            !(await route ~= HTTPRequest.make(path: "/chips"))
        )
    }

    @Test
    func method_Matches() async {
        let route = HTTPRoute("POST /fish/chips")

        #expect(
            await route ~= HTTPRequest.make(method: .POST, path: "/fish/chips")
        )

        #expect(
            await route ~= HTTPRequest.make(method: .init(rawValue: "post"), path: "/fish/chips/")
        )

        #expect(
            await route ~= HTTPRequest.make(method: "post", path: "/fish/chips/")
        )

        #expect(
            await route ~= HTTPRequest.make(method: "POST", path: "/fish/chips/")
        )

        #expect(
            !(await route ~= HTTPRequest.make(method: .GET, path: "/fish/chips"))
        )
    }

    @Test
    func wildcardMethod_Matches() async {
        let route = HTTPRoute("/fish/chips")

        #expect(
            await route ~= HTTPRequest.make(method: .POST, path: "/fish/chips")
        )

        #expect(
            await route ~= HTTPRequest.make(method: .GET, path: "/fish/chips/")
        )

        #expect(
            await route ~= HTTPRequest.make(method: .init("GET"), path: "/fish/chips")
        )

        #expect(
            !(await route ~= HTTPRequest.make(method: .GET, path: "/chips/"))
        )
    }

    @Test
    func wildcardMethod_MatchesRoute() async {
        let route = HTTPRoute("GET /mock")

        #expect(
            !(await route ~= HTTPRequest.make(method: HTTPMethod("GET"), path: "/"))
        )

        #expect(
            await route ~= HTTPRequest.make(method: HTTPMethod("GET"), path: "/mock")
        )

        #expect(
            !(await route ~= HTTPRequest.make(method: HTTPMethod("GET"), path: "/mock/fish"))
        )
    }

    @Test
    func emptyWildcard_MatchesAllRoutes() async {
        let route = HTTPRoute("*")

        #expect(
            await route ~= HTTPRequest.make(method: HTTPMethod("GET"),
                                      path: "/")
        )

        #expect(
            await route ~= HTTPRequest.make(method: HTTPMethod("GET"),
                                      path: "/mock")
        )

        #expect(
            await route ~= HTTPRequest.make(method: HTTPMethod("GET"),
                                      path: "/mock/fish")
        )
    }

    @Test
    func queryItem_MatchesRoute() async {
        let route = HTTPRoute("GET /mock?fish=chips")

        #expect(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "fish", value: "chips")])
        )

        #expect(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "cat", value: "dog"),
                                              .init(name: "fish", value: "squid"),
                                              .init(name: "fish", value: "chips")])
        )

        #expect(
            !(await route ~= HTTPRequest.make(method: .GET,
                                              path: "/mock",
                                              query: [
                                                .init(name: "cat", value: "dog"),
                                                .init(name: "fish", value: "squid")
                                              ]))
        )
    }

    @Test
    func multipleQueryItems_MatchesRoute() async {
        let route = HTTPRoute("GET /mock?fish=chips&cats=dogs")

        #expect(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [
                                        .init(name: "fish", value: "chips"),
                                        .init(name: "cats", value: "dogs")
                                      ])
        )

        #expect(
            await route ~= HTTPRequest.make(method: .GET,
                                            path: "/mock",
                                            query: [
                                                .init(name: "cats", value: "dogs"),
                                                .init(name: "fish", value: "chips")
                                            ])
        )

        #expect(
            !(await route ~= HTTPRequest.make(method: .GET,
                                              path: "/mock",
                                              query: [.init(name: "fish", value: "chips")]))
        )

        #expect(
            !(await route ~= HTTPRequest.make(method: .GET,
                                              path: "/mock",
                                              query: [.init(name: "cats", value: "dogs")]))
        )

        #expect(
            !(await route ~= HTTPRequest.make(method: .GET,
                                              path: "/mock",
                                              query: [
                                                .init(name: "cat", value: "dog"),
                                                .init(name: "fish", value: "squid")
                                              ]))
        )
    }

    @Test
    func queryItemWildcard_MatchesRoute() async {
        let route = HTTPRoute("GET /mock?fish=*")

        #expect(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "fish", value: "chips")])
        )

        #expect(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "cat", value: "dog"),
                                              .init(name: "fish", value: "squid"),
                                              .init(name: "fish", value: "chips")])
        )

        #expect(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      query: [.init(name: "cat", value: "dog"),
                                              .init(name: "fish", value: "squid")])
        )
        
        #expect(
             !(await route ~= HTTPRequest.make(method: .GET,
                                               path: "/mock",
                                               query: [.init(name: "cat", value: "dog")]))
         )
    }

    @Test
    func wildcardPathWithQueryItem_MatchesRoute() async {
        let route = HTTPRoute("/mock/*?fish=*")

        #expect(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock/anemone",
                                      query: [.init(name: "fish", value: "chips")])
        )

        #expect(
            await route ~= HTTPRequest.make(method: .POST,
                                      path: "/mock/crabs",
                                      query: [.init(name: "fish", value: "shrimp")])
        )

        #expect(
            !(await route ~= HTTPRequest.make(method: .GET,
                                              path: "/mock/anemone"))
        )
    }

    @Test
    func header_MatchesRoute() async {
        let route = HTTPRoute("GET /mock", headers: [.contentType: "json"])

        #expect(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.contentType: "json"])
        )

        #expect(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.contentType: "xml, json"])
        )

        #expect(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.contentEncoding: "xml",
                                                .contentType: "json"])
        )

        #expect(
            !(await route ~= HTTPRequest.make(method: .GET,
                                              path: "/mock",
                                              headers: [.contentType: "xml"]))
        )
    }

    @Test
    func multipleHeaders_MatchesRoute() async {
        let route = HTTPRoute("GET /mock", headers: [.host: "fish",
                                                     .contentType: "json"])

        #expect(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [
                                        .host: "fish",
                                        .contentType: "json"
                                      ])
        )

        #expect(
            await route ~= HTTPRequest.make(method: .GET,
                                            path: "/mock",
                                            headers: [
                                                .contentType: "json",
                                                .host: "fish"
                                            ])
        )

        #expect(
            !(await route ~= HTTPRequest.make(method: .GET,
                                              path: "/mock",
                                              headers: [.host: "fish"]))
        )

        #expect(
            !(await route ~= HTTPRequest.make(method: .GET,
                                              path: "/mock",
                                              headers: [.contentType: "json"]))
        )

        #expect(
            !(await route ~= HTTPRequest.make(method: .GET,
                                              path: "/mock",
                                              headers: [.contentType: "xml",
                                                        .host: "fish"]))
        )
    }

    @Test
    func headerWildcard_MatchesRoute() async {
        let route = HTTPRoute("GET /mock", headers: [.authorization: "*"])

        #expect(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.authorization: "Bearer abc"])
        )

        #expect(
            await route ~= HTTPRequest.make(method: .GET,
                                      path: "/mock",
                                      headers: [.authorization: "Bearer xyz"])
        )

        #expect(
            !(await route ~= HTTPRequest.make(method: .GET,
                                              path: "/mock",
                                              headers: [.contentType: "xml"]))
        )
    }

#if canImport(Darwin)
    @Test
    func body_MatchesRoute() async {
        let route = HTTPRoute("GET /mock", body: .json(where: "food == 'fish'"))

        #expect(
            await route ~= HTTPRequest.make(path: "/mock",
                                      body: #"{"age": 45, "food": "fish"}"#.data(using: .utf8)!)
        )

        #expect(
            await route ~= HTTPRequest.make(path: "/mock",
                                      body: #"{"food": "fish"}"#.data(using: .utf8)!)
        )

        #expect(
            !(await route ~= HTTPRequest.make(path: "/mock",
                                      body: #"{"age": 45}"#.data(using: .utf8)!))
        )
    }
#endif

    @Test
    func deprecated_Method() {
        #expect(HTTPRoute("/fish/*").method == .wildcard)
        #expect(HTTPRoute("GET /fish/*").method == .caseInsensitive("GET"))
        #expect(HTTPRoute("PUT /fish/*").method == .caseInsensitive("PUT"))
        #expect(HTTPRoute("GET,PUT /fish/*").method == .caseInsensitive("GET"))
    }

    @Test
    func routeParameters() {
        let route = HTTPRoute("GET /mock/:id")
        let parameters = route.parameters
        #expect(parameters.count == 1)
        #expect(parameters["id"] == .path(name: "id", index: 1)) // Position 1 in the components array

        let route2 = HTTPRoute("GET /mock/:id/:bloop/hello/guys/:zonk")
        let parameters2 = route2.parameters
        #expect(parameters2.count == 3)
        #expect(parameters2["id"] == .path(name: "id", index: 1))
        #expect(parameters2["bloop"] == .path(name: "bloop", index: 2))
        #expect(parameters2["zonk"] == .path(name: "zonk", index: 5))

        let route3 = HTTPRoute("GET /mock/:id/not:bloop/hello/guys/:zonk")
        let parameters3 = route3.parameters
        #expect(parameters3.count == 2)
        #expect(parameters3["id"] == .path(name: "id", index: 1))
        #expect(parameters3["bloop"] == nil)
        #expect(parameters2["zonk"] == .path(name: "zonk", index: 5))

        let route4 = HTTPRoute("GET /mock/:id?food=:fish")
        let parameters4 = route4.parameters
        #expect(parameters4.count == 2)
        #expect(parameters4["id"] == .path(name: "id", index: 1))
        #expect(parameters4["fish"] == .query(name: "fish", index: "food"))
    }

    @Test
    func routeParameterValues() {
        let route = HTTPRoute("GET /mock/:id?foo=:foo&bar=:bar")

        #expect(
            route.extractParameters(from: .make("/mock/15?foo=🐟&bar=🍤")) == [
                .init(name: "id", value: "15"),
                .init(name: "foo", value: "🐟"),
                .init(name: "bar", value: "🍤")
            ]
        )

        #expect(
            route.extractParameters(from: .make("/mock/99?bar=🐠&foo=🍟")) == [
                .init(name: "id", value: "99"),
                .init(name: "foo", value: "🍟"),
                .init(name: "bar", value: "🐠")
            ]
        )

        #expect(
            route.extractParameters(from: .make("/mock?bar=🐠")) == [
                .init(name: "bar", value: "🐠")
            ]
        )
    }

    @Test
    func routeParameterValuesA() {
        let route = HTTPRoute("GET /:foo/:bar")
        enum Beast: String, HTTPRouteParameterValue {
            case fish
        }

        #expect(
            route.extractParameters(from: .make("/10/fish"))["foo"] == 10
        )
        #expect(
            route.extractParameters(from: .make("/20/fish"))["bar"] == "fish"
        )
        #expect(
            route.extractParameters(from: .make("/20/fish"))["bar"] == Beast.fish
        )
    }

    @Test
    func pathParameters() throws {
        // given
        let route = HTTPRoute("GET /mock/:id/hello/:zonk")
        let request = HTTPRequest.make(path: "/mock/12/hello/fish")

        #expect(
            try route.extractParameterValues(from: request) == (12, "fish")
        )

        #expect(
            try route.extractParameterValues(from: request) == (12)
        )

        #expect(throws: (any Error).self) {
            try route.extractParameterValues(of: (Int, Int).self, from: request)
        }

        #expect(throws: (any Error).self) {
            try route.extractParameterValues(of: (Int, String, String).self, from: request)
        }
    }

    @Test
    func description() {
        #expect(
            HTTPRoute("GET /mock/:id/hello/:zonk").description == "GET /mock/:id/hello/:zonk"
        )
        #expect(
            HTTPRoute("/mock/*").description == "/mock/*"
        )
        #expect(
            HTTPRoute("FUZZ,TRACE,GET /mock?hello=*").description == "GET,TRACE,FUZZ /mock?hello=*"
        )
    }
}
