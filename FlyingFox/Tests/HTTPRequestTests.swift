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
import Foundation
import Testing

struct HTTPRequestTests {

    @Test
    func requestBodyData_CanBeChanged() async throws {
        // when
        var request = HTTPRequest.make(body: Data([0x01, 0x02]))

        // then
        #expect(
            try await request.bodyData == Data([0x01, 0x02])
        )

        // when
        request.setBodyData(Data([0x05, 0x06]))

        // then
        #expect(
            try await request.bodyData == Data([0x05, 0x06])
        )
    }

    @Test
    func targetIsCreated() {
        // when
        let request = HTTPRequest.make(path: "/meal plan/order", query: [
            .init(name: "food", value: "fish & chips"),
            .init(name: "qty", value: "15")
        ])

        // then
        #expect(request.target.rawValue == "/meal%20plan/order?food=fish%20%26%20chips&qty=15")
        #expect(request.target.path() == "/meal%20plan/order")
        #expect(request.target.path(percentEncoded: false) == "/meal plan/order")
        #expect(request.target.query() == "food=fish%20%26%20chips&qty=15")
        #expect(request.target.query(percentEncoded: false) == "food=fish & chips&qty=15")
    }

    @Test
    func pathIsCreated() {
        // when
        let request = HTTPRequest.make(
            target: "/meal%20plan/order?food=fish%20%26%20chips&qty=15"
        )

        // then
        #expect(request.path == "/meal plan/order")
        #expect(request.query == [
            .init(name: "food", value: "fish & chips"),
            .init(name: "qty", value: "15")
        ])
        #expect(request.target.path() == "/meal%20plan/order")
        #expect(request.target.path(percentEncoded: false) == "/meal plan/order")
        #expect(request.target.query() == "food=fish%20%26%20chips&qty=15")
        #expect(request.target.query(percentEncoded: false) == "food=fish & chips&qty=15")
    }

    // RFC 9112 §9.3 — HTTP/1.1 connections persist by default; only `Connection: close` opts out.
    @Test
    func http11_keepsAliveByDefault_whenConnectionHeaderAbsent() {
        let request = HTTPRequest.make(version: .http11, headers: [:])
        #expect(request.shouldKeepAlive)
    }

    @Test
    func http11_closes_whenConnectionHeaderIsClose() {
        let request = HTTPRequest.make(version: .http11, headers: [.connection: "close"])
        #expect(!request.shouldKeepAlive)
    }

    @Test
    func http11_closes_whenConnectionHeaderIsCloseMixedCase() {
        let request = HTTPRequest.make(version: .http11, headers: [.connection: "Close"])
        #expect(!request.shouldKeepAlive)
    }

    @Test
    func http11_keepsAlive_whenConnectionHeaderIsKeepAlive() {
        let request = HTTPRequest.make(version: .http11, headers: [.connection: "keep-alive"])
        #expect(request.shouldKeepAlive)
    }

    // RFC 9110 §7.6.1 — Connection is a comma-separated list of options.
    @Test
    func http11_keepsAlive_withMultiTokenConnectionHeader() {
        let request = HTTPRequest.make(version: .http11, headers: [.connection: "keep-alive, Upgrade"])
        #expect(request.shouldKeepAlive)
    }

    @Test
    func http11_closes_whenCloseTokenAppearsAmongOthers() {
        let request = HTTPRequest.make(version: .http11, headers: [.connection: "Upgrade, close"])
        #expect(!request.shouldKeepAlive)
    }

    // RFC 9112 §9.3 — HTTP/1.0 closes by default; only `Connection: keep-alive` opts in.
    @Test
    func http10_closesByDefault_whenConnectionHeaderAbsent() {
        let request = HTTPRequest.make(version: HTTPVersion("HTTP/1.0"), headers: [:])
        #expect(!request.shouldKeepAlive)
    }

    @Test
    func http10_keepsAlive_whenConnectionHeaderIsKeepAlive() {
        let request = HTTPRequest.make(version: HTTPVersion("HTTP/1.0"), headers: [.connection: "keep-alive"])
        #expect(request.shouldKeepAlive)
    }

    @Test
    func http10_closes_whenConnectionHeaderIsClose() {
        let request = HTTPRequest.make(version: HTTPVersion("HTTP/1.0"), headers: [.connection: "close"])
        #expect(!request.shouldKeepAlive)
    }
}
