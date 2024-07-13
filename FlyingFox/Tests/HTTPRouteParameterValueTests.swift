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
import XCTest

final class HTTPRouteParameterValueTests: XCTestCase {

    func testBoolConversion() {
        XCTAssertTrue(
            try Bool(parameter: "true")
        )
        XCTAssertTrue(
            try Bool(parameter: "TRUE")
        )
        XCTAssertFalse(
            try Bool(parameter: "false")
        )
        XCTAssertFalse(
            try Bool(parameter: "FALSE")
        )

        XCTAssertThrowsError(
            try Bool(parameter: "fish")
        )
    }

    func testStringConversion() {
        XCTAssertEqual(
            String(parameter: "fish"),
            "fish"
        )
    }

    func testIntConversion() {
        XCTAssertEqual(
            try Int8(parameter: "100"),
            100
        )
        XCTAssertEqual(
            try Int8(parameter: "-100"),
            -100
        )
        XCTAssertEqual(
            try Int16(parameter: "10000"),
            10000
        )
        XCTAssertEqual(
            try Int16(parameter: "-10000"),
            -10000
        )
        XCTAssertEqual(
            try Int32(parameter: "1000000000"),
            1000000000
        )
        XCTAssertEqual(
            try Int32(parameter: "-1000000000"),
            -1000000000
        )
        XCTAssertEqual(
            try Int64(parameter: "1000000000000"),
            1000000000000
        )
        XCTAssertEqual(
            try Int64(parameter: "-1000000000000"),
            -1000000000000
        )

        XCTAssertThrowsError(
            try Int8(parameter: "1000")
        )
        XCTAssertThrowsError(
            try Int8(parameter: "fish")
        )
        XCTAssertThrowsError(
            try Int16(parameter: "1000000000")
        )
        XCTAssertThrowsError(
            try Int16(parameter: "fish")
        )
        XCTAssertThrowsError(
            try Int32(parameter: "1000000000000")
        )
        XCTAssertThrowsError(
            try Int32(parameter: "fish")
        )
        XCTAssertThrowsError(
            try Int64(parameter: "1000000000000000000000")
        )
        XCTAssertThrowsError(
            try Int64(parameter: "fish")
        )
    }

    func testUIntConversion() {
        XCTAssertEqual(
            try UInt8(parameter: "100"),
            100
        )
        XCTAssertEqual(
            try UInt16(parameter: "10000"),
            10000
        )
        XCTAssertEqual(
            try UInt32(parameter: "1000000000"),
            1000000000
        )
        XCTAssertEqual(
            try UInt64(parameter: "1000000000000"),
            1000000000000
        )

        XCTAssertThrowsError(
            try UInt8(parameter: "1000")
        )
        XCTAssertThrowsError(
            try UInt8(parameter: "fish")
        )
        XCTAssertThrowsError(
            try UInt16(parameter: "1000000000")
        )
        XCTAssertThrowsError(
            try UInt16(parameter: "fish")
        )
        XCTAssertThrowsError(
            try UInt32(parameter: "1000000000000")
        )
        XCTAssertThrowsError(
            try UInt32(parameter: "fish")
        )
        XCTAssertThrowsError(
            try UInt64(parameter: "1000000000000000000000")
        )
        XCTAssertThrowsError(
            try UInt64(parameter: "fish")
        )
    }

    func testDoubleConversion() {
        XCTAssertEqual(
            try Double(parameter: "10.5"),
            10.5
        )
        XCTAssertEqual(
            try Double(parameter: "-10.5"),
            -10.5
        )

        XCTAssertThrowsError(
            try Double(parameter: "fish")
        )
    }

    func testFloatConversion() {
        XCTAssertEqual(
            try Float(parameter: "10.5"),
            10.5
        )
        XCTAssertEqual(
            try Float(parameter: "-10.5"),
            -10.5
        )

        XCTAssertThrowsError(
            try Float(parameter: "fish")
        )
    }

    func testFloat32Conversion() {
        XCTAssertEqual(
            try Float32(parameter: "10.5"),
            10.5
        )
        XCTAssertEqual(
            try Float32(parameter: "-10.5"),
            -10.5
        )

        XCTAssertThrowsError(
            try Float32(parameter: "fish")
        )
    }

    func testEnumConversion() {
        enum Food: String, HTTPRouteParameterValue {
            case fish
            case chips
        }

        XCTAssertEqual(
            try Food(parameter: "fish"),
            .fish
        )
        XCTAssertEqual(
            try Food(parameter: "chips"),
            .chips
        )

        XCTAssertThrowsError(
            try Food(parameter: "10")
        )
    }
}

private enum Food: String, HTTPRouteParameterValue {
    case fish
    case chips
}
