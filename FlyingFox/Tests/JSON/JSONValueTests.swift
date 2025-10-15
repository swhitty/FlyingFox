//
//  JSONValueTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 29/05/2023.
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

import FlyingFox
import Foundation
import Testing

struct JSONValueTests {

    @Test
    func json_string() throws {
        // given
        let val = try JSONValue("fish")

        // then
        #expect(val == "fish")
        #expect(val != "chips")
    }

    @Test
    func json_int() throws {
        // given
        let val = try JSONValue(Int(10))

        // then
        #expect(val == 10)
        #expect(val != 100)
    }

    @Test
    func json_double() throws {
        // given
        let val = try JSONValue(10.5)

        // then
        #expect(val == 10.5)
        #expect(val != 100.5)
    }

    @Test
    func json_bool() throws {
        // given
        let val = try JSONValue(true)

        // then
        #expect(val == true)
        #expect(val != false)
    }

    @Test
    func json_nsnull() throws {
        // given
        let val = try JSONValue(NSNull())

        // then
        #expect(val == .null)
        #expect(val != "fish")
    }

    @Test
    func json_anyNone() throws {
        // given
        let val = try JSONValue(String?.none as Any)

        // then
        #expect(val == .null)
        #expect(val != "fish")
    }

    @Test
    func json_optionalNone() throws {
        // given
        let val = try JSONValue(String?.none)

        // then
        #expect(val == .null)
        #expect(val != "fish")
    }

    @Test
    func json_optionalSome() throws {
        // given
        let val = try JSONValue(String?.some("fish"))

        // then
        #expect(val == "fish")
        #expect(val != .null)
    }

    @Test
    func json_invalid() {
        #expect(throws: (any Error).self) {
            try JSONValue(HTTPRequest.make())
        }
    }

    #if canImport(Darwin)
    @Test
    func parses_JSON5() throws {
        // given
        let data = #"""
        {
            // comment
            id: 5
        }
        """#.data(using: .utf8)!

        // when then
        #expect(
            try JSONValue(data: data) == .object(["id": .number(5)])
        )
    }
    #endif
}
