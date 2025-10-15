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
import Testing

struct JSONValueTests {

    @Test
    func objects_CanBeUpdated_ToNull() throws {
        // given
        var val = JSONValue.object([:])

        // when
        try val.updateValue(parsing: "null")

        // then
        #expect(val == .null)
    }

    @Test
    func arrays_CanBeUpdated_ToNull() throws {
        // given
        var val = JSONValue.array([])

        // when
        try val.updateValue(parsing: "null")

        // then
        #expect(val == .null)
    }

    @Test
    func string_CanBeUpdated_ToNull() throws {
        // given
        var val = JSONValue.string("")

        // when
        try val.updateValue(parsing: "null")

        // then
        #expect(val == .null)
    }

    @Test
    func number_CanBeUpdated_ToNull() throws {
        // given
        var val = JSONValue.number(10)

        // when
        try val.updateValue(parsing: "null")

        // then
        #expect(val == .null)
    }

    @Test
    func bool_CanBeUpdated_ToNull() throws {
        // given
        var val = JSONValue.boolean(true)

        // when
        try val.updateValue(parsing: "null")

        // then
        #expect(val == .null)
    }

    @Test
    func null_CanBeUpdated_ToNull() throws {
        // given
        var val = JSONValue.null

        // when
        try val.updateValue(parsing: "null")

        // then
        #expect(val == .null)
    }

    @Test
    func null_CanBeUpdated_ToObject() throws {
        // given
        var val = JSONValue.null

        // when
        try val.updateValue(parsing: "{\"foo\":\"bar\"}")

        // then
        #expect(val == .object(["foo": .string("bar")]))
    }

    @Test
    func null_CanBeUpdated_ToArray() throws {
        // given
        var val = JSONValue.null

        // when
        try val.updateValue(parsing: "[1,2]")

        // then
        #expect(val == .array([.number(1), .number(2)]))
    }

    @Test
    func null_CanBeUpdated_ToNumber() throws {
        // given
        var val = JSONValue.null

        // when
        try val.updateValue(parsing: "1")

        // then
        #expect(val == .number(1))
    }

    @Test
    func null_CanBeUpdated_ToBool() throws {
        // given
        var val = JSONValue.null

        // when
        try val.updateValue(parsing: "true")

        // then
        #expect(val == .boolean(true))
    }

    @Test
    func null_CanBeUpdated_ToString() throws {
        // given
        var val = JSONValue.null

        // when
        try val.updateValue(parsing: "foo")

        // then
        #expect(val == .string("foo"))
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
