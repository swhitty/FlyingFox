//
//  HTTPRequest+Adress.swift
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


import Foundation
import FlyingSocks

public extension HTTPRequest {

    enum Address: Sendable, Hashable {
        case ip4(String, port: UInt16)
        case ip6(String, port: UInt16)
        case unix(String)
    }

    var remoteIPAddress: String? {
        if let forwarded = headers[.xForwardedFor]?.split(separator: ",").first {
            return String(forwarded)
        }
        switch remoteAddress {
        case let .ip4(ip, port: _),
             let .ip6(ip, port: _):
            return ip
        case .unix, .none:
            return nil
        }
    }
}

public extension HTTPRequest.Address {

    static func make(from address: Socket.Address) -> Self {
        switch address {
        case let .ip4(ip, port: port):
            return .ip4(ip, port: port)
        case let .ip6(ip, port: port):
            return .ip6(ip, port: port)
        case let .unix(path):
            return .unix(path)
        }
    }
}
