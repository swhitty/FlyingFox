//
//  WSFrame.swift
//  FlyingFox
//
//  Created by Simon Whitty on 16/03/2022.
//  Copyright © 2022 Simon Whitty. All rights reserved.
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

public struct WSFrame: Sendable, Hashable {
    public var fin: Bool
    public var rsv1: Bool
    public var rsv2: Bool
    public var rsv3: Bool
    public var opcode: Opcode
    public var mask: Mask?
    @UncheckedSendable
    public var payload: Data

    public init(fin: Bool,
                rsv1: Bool,
                rsv2: Bool,
                rsv3: Bool,
                opcode: Opcode,
                mask: Mask?,
                payload: Data) {
        self.fin = fin
        self.rsv1 = rsv1
        self.rsv2 = rsv2
        self.rsv3 = rsv3
        self.opcode = opcode
        self.mask = mask
        self.payload = payload
    }

    public struct Opcode: Sendable, RawRepresentable, Hashable {
        public var rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public init(_ rawValue: UInt8) {
            self.init(rawValue: rawValue)
        }

        public static let continuation = Opcode(0x0)
        public static let text         = Opcode(0x1)
        public static let binary       = Opcode(0x2)
        public static let close        = Opcode(0x8)
        public static let ping         = Opcode(0x9)
        public static let pong         = Opcode(0xA)
    }

    public struct Mask: Sendable, Hashable {
        public var m1: UInt8
        public var m2: UInt8
        public var m3: UInt8
        public var m4: UInt8

        public init(m1: UInt8, m2: UInt8, m3: UInt8, m4: UInt8) {
            self.m1 = m1
            self.m2 = m2
            self.m3 = m3
            self.m4 = m4
        }
    }
}
