//
//  HTTPRequest+AddressTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 03/08/2024.
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

struct HTTPRequestAddressTests {

    typealias Address = HTTPRequest.Address

    @Test
    func remoteAddress_IP4() {
        let request = HTTPRequest.make(remoteAddress: .ip4("fish", port: 80))
        #expect(request.remoteAddress == .ip4("fish", port: 80))
        #expect(request.remoteIPAddress == "fish")
    }

    @Test
    func remoteAddress_IP6() {
        let request = HTTPRequest.make(remoteAddress: .ip6("chips", port: 8080))
        #expect(request.remoteAddress == .ip6("chips", port: 8080))
        #expect(request.remoteIPAddress == "chips")
    }

    @Test
    func remoteAddress_Unix() {
        let request = HTTPRequest.make(remoteAddress: .unix("shrimp"))
        #expect(request.remoteAddress == .unix("shrimp"))
        #expect(request.remoteIPAddress == nil)
    }

    @Test
    func remoteAddress_XForwardedFor() {
        let request = HTTPRequest.make(
            headers: [.xForwardedFor: "fish, chips"],
            remoteAddress: .ip4("shrimp", port: 80)
        )
        #expect(request.remoteAddress == .ip4("shrimp", port: 80))
        #expect(request.remoteIPAddress == "fish")
    }
}
