//
//  HTTPRoute+withRouteTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 15/09/2025.
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

struct HTTPRouteWithRouteTests {

    @Test
    func handleMatchedRequest_matches() async throws {
        // given
        let request = HTTPRequest.make("/10/hello?food=fish&qty=🐟")
        let route = HTTPRoute("GET /:id/hello?food=:food&qty=:qty")

        // when
        let res = await withRoute(route, matching: request) {
            (
                id: request.routeParameters["id"],
                food: request.routeParameters["food"],
                qty: request.routeParameters["qty"]
            )
        }

        // then
        #expect(res?.id == "10")
        #expect(res?.food == "fish")
        #expect(res?.qty == "🐟")
    }

    @Test
    func handleMatchedRequest_skips() async {
        // given
        let request = HTTPRequest.make("/chips")
        let route = HTTPRoute("GET /fish")

        // when
        let didMatch = await withRoute(route, matching: request) {
            true
        }

        // then
        #expect(didMatch == nil)
    }
}
