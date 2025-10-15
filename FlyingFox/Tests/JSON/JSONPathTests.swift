//
//  JSONPathTests.swift
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

@testable import FlyingFox
import Testing

struct JSONPathTests {

    @Test
    func parsesPath() throws {
        #expect(
            try JSONPath(parsing: "$.name").components == [.field("name")]
        )
        #expect(
            try JSONPath(parsing: "$.users[4].name").components == [.field("users"), .array(4), .field("name")]
        )
        #expect(
            try JSONPath(parsing: "$[4].name").components == [.array(4), .field("name")]
        )
    }

    @Test
    func throwsError_For_InvalidPath() {
        #expect(throws: (any Swift.Error).self) {
            try JSONPath(parsing: ".name")
        }
        #expect(throws: (any Swift.Error).self) {
            try JSONPath(parsing: "$.users[4")
        }
    }

    @Test
    func booleanIsPreserved() throws {
        let json = try JSONValue(json: #"""
        {"isActive": true}
        """#)
        #expect(
            json == .object(["isActive": .boolean(true)])
        )
    }

    @Test
    func getValue() throws {
        let json = try JSONValue(json: #"""
        {
            "owner": {
                "age": 7,
                "food": "fish",
                "isAdmin": true
             },
            "users": [
                {"food": "fish"},
                {"food": "chips"},
                {"age": 9}
            ]
        }
        """#)

        #expect(
            try json.getValue(for: "$.owner.age") == 7
        )
        #expect(
            try json.getValue(for: "$.owner.isAdmin") == true
        )
        #expect(
            try json.getValue(for: "$.users[1].food") == "chips"
        )
        #expect(
            try json.getValue(for: "$.users[2].age") == 9
        )
    }

    @Test
    func setValue() throws {
        var json = try JSONValue(json: #"""
        {
            "owner": {
                "age": 7,
                "food": "fish",
                "isAdmin": true
             },
            "users": [
                {"food": "fish"},
                {"food": "chips"},
                {"age": 9}
            ]
        }
        """#)

        try json.setValue(.number(10), for: "$.users[2].age")
        try json.setValue(.boolean(false), for: "$.owner.isAdmin")
        try json.setValue(.object(["name": JSONValue("shrimp")]), for: "$.users[2]")

        #expect(
            try json.makeJSON() == #"""
            {
              "owner" : {
                "age" : 7,
                "food" : "fish",
                "isAdmin" : false
              },
              "users" : [
                {
                  "food" : "fish"
                },
                {
                  "food" : "chips"
                },
                {
                  "name" : "shrimp"
                }
              ]
            }
            """#
        )
    }
}

private extension JSONValue {
    init(json: String) throws {
        try self.init(data: json.data(using: .utf8)!)
    }

    func makeJSON() throws -> String {
        let data = try makeData(options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8)!
    }
}
