//
//  HTTPRequestTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 02/04/2023.
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
import XCTest

final class HTTPRequestTests: XCTestCase {

    func testRequestBodyData_CanBeChanged() async {
        // when
        var request = HTTPRequest.make(body: Data([0x01, 0x02]))

        // then
        await AsyncAssertEqual(
            try await request.bodyData,
            Data([0x01, 0x02])
        )

        // when
        request.setBodyData(Data([0x05, 0x06]))

        // then
        await AsyncAssertEqual(
            try await request.bodyData,
            Data([0x05, 0x06])
        )
    }

    func testDeprecatedBodyProperty() {
        // when
        var request = HTTPRequest.make(body: Data([0x01, 0x02]))

        // then
        XCTAssertEqual(
            request.body,
            Data([0x01, 0x02])
        )

        // when
        request.body = Data([0x04, 0x05])

        // then
        XCTAssertEqual(
            request.body,
            Data([0x04, 0x05])
        )
    }
}
