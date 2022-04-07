//
//  SHA1.swift
//  FlyingFox
//
//  Created by Simon Whitty on 17/03/2022.
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

#if canImport(CryptoKit)
import CryptoKit
#endif

import Foundation

struct SHA1 { }

#if canImport(CryptoKit)
extension SHA1 {
    static func hash<D: DataProtocol>(data: D) -> Data {
        Data(Insecure.SHA1.hash(data: data))
    }
}
#else

extension SHA1 {

    private struct Digest {
        var h: [UInt32] = [0x67452301,
                           0xEFCDAB89,
                           0x98BADCFE,
                           0x10325476,
                           0xC3D2E1F0]

        mutating func process(slice: inout ContiguousArray<UInt32>) {
            for i in 0..<16 {
                slice[i] = slice[i].bigEndian
            }
            for i in 16...79 {
                slice[i] = rotateLeft(slice[i-3] ^ slice[i-8] ^ slice[i-14] ^ slice[i-16], 1)
            }
            var a,b,c,d,e,f,k,temp:UInt32
            a=h[0]; b=h[1]; c=h[2]; d=h[3]; e=h[4]
            f=0x0; k=0x0

            for i in 0...79 {
                switch i {
                case 0...19:
                    f = (b & c) | ((~b) & d)
                    k = 0x5A827999
                case 20...39:
                    f = b ^ c ^ d
                    k = 0x6ED9EBA1
                case 40...59:
                    f = (b & c) | (b & d) | (c & d)
                    k = 0x8F1BBCDC
                default:
                    f = b ^ c ^ d
                    k = 0xCA62C1D6
                }
                temp = rotateLeft(a, 5) &+ f &+ e &+ k &+ slice[i]
                e = d
                d = c
                c = rotateLeft(b, 30)
                b = a
                a = temp
            }
            h[0] = h[0] &+ a
            h[1] = h[1] &+ b
            h[2] = h[2] &+ c
            h[3] = h[3] &+ d
            h[4] = h[4] &+ e
        }
    }

    static func hash<D: DataProtocol>(data: D) -> Data where D.Index == Int {
        // Convert the data to regular data in case it was a slice because slices can crash this hash algorithm
        let data = Data(data)

        var digest = Digest()
        var w = ContiguousArray<UInt32>(repeating: 0, count: 80)

        for idx in stride(from: 0, to: data.count, by: 64) {
            let end = idx + 64
            guard end <= data.count else { break }
            _ = w.withUnsafeMutableBufferPointer {
                data[idx..<end].copyBytes(to: $0)
            }
            digest.process(slice: &w)
        }

        let remainder = data.count % 64
        w = ContiguousArray<UInt32>(repeating: 0, count: 80)
        _ = w.withUnsafeMutableBufferPointer {
            data.suffix(remainder).copyBytes(to: $0)
        }

        let bytetochange = remainder % 4
        w[remainder / 4] |= 0x80 << UInt32(bytetochange * 8)

        if remainder >= 56 {
            digest.process(slice: &w)
            w = ContiguousArray<UInt32>(repeating: 0, count: 80)
        }
        w[15] = UInt32(data.count * 8).bigEndian
        digest.process(slice: &w)
        return Data(digest.h.flatMap(\.bytes))
    }

    private static func rotateLeft(_ lhs: UInt32, _ rhs: UInt32) -> UInt32 {
        lhs << rhs | lhs >> (32-rhs)
    }
}

private extension UInt32 {
    var bytes: [UInt8] {
        [
            UInt8(self >> 24 & 0xFF),
            UInt8(self >> 16 & 0xFF),
            UInt8(self >> 8 & 0xFF),
            UInt8(self >> 0 & 0xFF)
        ]
    }
}

#endif
