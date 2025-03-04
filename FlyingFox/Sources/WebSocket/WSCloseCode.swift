//
//  WSCloseCode.swift
//  FlyingFox
//
//  Created by Simon Whitty on 04/03/2025.
//  Copyright © 2025 Simon Whitty. All rights reserved.
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

public struct WSCloseCode: RawRepresentable, Sendable, Hashable {
    public var rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public init(_ code: UInt16) {
        self.rawValue = code
    }
}

public extension WSCloseCode {
    // The following codes are based on:
    // https://developer.mozilla.org/en-US/docs/Web/API/CloseEvent/code

    static let normalClosure = WSCloseCode(1000)
    static let goingAway = WSCloseCode(1001)
    static let protocolError = WSCloseCode(1002)
    static let unsupportedData = WSCloseCode(1003)
    static let noStatusReceived = WSCloseCode(1005)
    static let abnormalClosure = WSCloseCode(1006)
    static let invalidFramePayloadData = WSCloseCode(1007)
    static let policyViolation = WSCloseCode(1008)
    static let messageTooBig = WSCloseCode(1009)
    static let mandatoryExtensionMissing = WSCloseCode(1010)
    static let internalServerError = WSCloseCode(1011)
    static let serviceRestart = WSCloseCode(1012)
    static let tryAgainLater = WSCloseCode(1013)
    static let badGateway = WSCloseCode(1014)
    static let tlsHandshakeFailure = WSCloseCode(1015)
}
