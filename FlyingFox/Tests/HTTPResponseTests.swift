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
import FlyingSocks
import Foundation
import Testing

struct HTTPResponseTests {

    @Test
    func completeBodyData() async throws {
        // given
        let response = HTTPResponse.make(body: Data([0x01, 0x02]))

        // then
        #expect(
            try await response.bodyData == Data([0x01, 0x02])
        )
    }

    @Test
    func sequenceBodyData() async throws {
        // given
        let buffer = ConsumingAsyncSequence(
            bytes: [0x5, 0x6]
        )
        let sequence = HTTPBodySequence(from: buffer, count: 2, suggestedBufferSize: 2)
        let response = HTTPResponse.make(body: sequence)

        // then
        #expect(
            try await response.bodyData == Data([0x5, 0x6])
        )
    }

    @Test
    func webSocketBodyData() async throws {
        // given
        let response = HTTPResponse.make(webSocket: MessageFrameWSHandler.make())

        // then
        #expect(
            try await response.bodyData == Data()
        )
    }

    @Test
    func unknownRouteParameter() async {
        #expect(HTTPRequest.make().routeParameters["unknown"] == nil)
    }
}
