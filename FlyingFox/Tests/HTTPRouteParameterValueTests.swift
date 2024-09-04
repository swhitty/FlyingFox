//
//  HTTPRouteParameterValueTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 13/07/2024.
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

struct HTTPRouteParameterValueTests {

    @Test
    func boolConversion() throws {
        #expect(
            try Bool(parameter: "true")
        )
        #expect(
            try Bool(parameter: "TRUE")
        )
        #expect(
            try Bool(parameter: "false") == false
        )
        #expect(
            try Bool(parameter: "FALSE") == false
        )

        #expect(throws: (any Error).self) {
            try Bool(parameter: "fish")
        }
    }

    @Test
    func stringConversion() {
        #expect(
            String(parameter: "fish") == "fish"
        )
    }

    @Test
    func intConversion() throws {
        #expect(
            try Int8(parameter: "100") == 100
        )
        #expect(
            try Int8(parameter: "-100") == -100
        )
        #expect(
            try Int16(parameter: "10000") == 10000
        )
        #expect(
            try Int16(parameter: "-10000") == -10000
        )
        #expect(
            try Int32(parameter: "1000000000") == 1000000000
        )
        #expect(
            try Int32(parameter: "-1000000000") == -1000000000
        )
        #expect(
            try Int64(parameter: "1000000000000") == 1000000000000
        )
        #expect(
            try Int64(parameter: "-1000000000000") == -1000000000000
        )

        #expect(throws: (any Error).self) {
            try Int8(parameter: "1000")
        }
        #expect(throws: (any Error).self) {
            try Int8(parameter: "fish")
        }
        #expect(throws: (any Error).self) {
            try Int16(parameter: "1000000000")
        }
        #expect(throws: (any Error).self) {
            try Int16(parameter: "fish")
        }
        #expect(throws: (any Error).self) {
            try Int32(parameter: "1000000000000")
        }
        #expect(throws: (any Error).self) {
            try Int32(parameter: "fish")
        }
        #expect(throws: (any Error).self) {
            try Int64(parameter: "1000000000000000000000")
        }
        #expect(throws: (any Error).self) {
            try Int64(parameter: "fish")
        }
    }

    @Test
    func uIntConversion() throws {
        #expect(
            try UInt8(parameter: "100") == 100
        )
        #expect(
            try UInt16(parameter: "10000") == 10000
        )
        #expect(
            try UInt32(parameter: "1000000000") == 1000000000
        )
        #expect(
            try UInt64(parameter: "1000000000000") == 1000000000000
        )

        #expect(throws: (any Error).self) {
            try UInt8(parameter: "1000")
        }
        #expect(throws: (any Error).self) {
            try UInt8(parameter: "fish")
        }
        #expect(throws: (any Error).self) {
            try UInt16(parameter: "1000000000")
        }
        #expect(throws: (any Error).self) {
            try UInt16(parameter: "fish")
        }
        #expect(throws: (any Error).self) {
            try UInt32(parameter: "1000000000000")
        }
        #expect(throws: (any Error).self) {
            try UInt32(parameter: "fish")
        }
        #expect(throws: (any Error).self) {
            try UInt64(parameter: "1000000000000000000000")
        }
        #expect(throws: (any Error).self) {
            try UInt64(parameter: "fish")
        }
    }

    @Test
    func doubleConversion() throws {
        #expect(
            try Double(parameter: "10.5") == 10.5
        )
        #expect(
            try Double(parameter: "-10.5") == -10.5
        )

        #expect(throws: (any Error).self) {
            try Double(parameter: "fish")
        }
    }

    @Test
    func floatConversion() throws {
        #expect(
            try Float(parameter: "10.5") == 10.5
        )
        #expect(
            try Float(parameter: "-10.5") == -10.5
        )

        #expect(throws: (any Error).self) {
            try Float(parameter: "fish")
        }
    }

    @Test
    func float32Conversion() throws {
        #expect(
            try Float32(parameter: "10.5") == 10.5
        )
        #expect(
            try Float32(parameter: "-10.5") == -10.5
        )

        #expect(throws: (any Error).self) {
            try Float32(parameter: "fish")
        }
    }

    @Test
    func enumConversion() throws {
        enum Food: String, HTTPRouteParameterValue {
            case fish
            case chips
        }

        #expect(
            try Food(parameter: "fish") == .fish
        )
        #expect(
            try Food(parameter: "chips") == .chips
        )

        #expect(throws: (any Error).self) {
            try Food(parameter: "10")
        }
    }
}

private enum Food: String, HTTPRouteParameterValue {
    case fish
    case chips
}
