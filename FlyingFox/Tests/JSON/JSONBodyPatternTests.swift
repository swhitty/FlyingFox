//
//  JSONBodyPatternTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 15/08/2024.
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
import Foundation
import Testing

struct JSONBodyPatternTests {

    @Test
    func pattern_MatchesJSONPath() async throws {
        // given
        let pattern = JSONBodyPattern { $0["$.name"] == "fish" }

        // when then
        #expect(pattern.evaluate(json: #"{"name": "fish"}"#))
        #expect(pattern.evaluate(json: #"{"id": 5, "name": "fish"}"#))
        #expect(!pattern.evaluate(json: #"{"name": "chips"}"#))
        #expect(!pattern.evaluate(json: #"{}"#))
        #expect(!pattern.evaluate(json: #""#))
    }

    @Test
    func route_MatchesJSONPath() async throws {
        // given
        let route = HTTPRoute(
            "POST /fish",
            jsonBody: { $0["$.food"] == "chips"  }
        )

        // when
        var result = await route ~= .make(path: "fish", bodyJSON: #"{"food": "chips"}"#)

        // then
        #expect(result)

        // when
        result = await route ~= .make(path: "fish", bodyJSON: #"{"food": "shrimp"}"#)

        // then
        #expect(!result)
    }
}

private extension JSONBodyPattern {

    func evaluate(json: String) -> Bool {
        self.evaluate(Data(json.utf8))
    }
}

private extension HTTPRequest {
    static func make(method: HTTPMethod = .POST,
                     version: HTTPVersion = .http11,
                     path: String = "/",
                     query: [QueryItem] = [],
                     headers: [HTTPHeader: String] = [:],
                     bodyJSON: String) -> Self {
        HTTPRequest(method: method,
                    version: version,
                    path: path,
                    query: query,
                    headers: headers,
                    body: Data(bodyJSON.utf8))
    }
}
