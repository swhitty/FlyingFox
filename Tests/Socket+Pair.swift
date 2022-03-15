//
//  Socket+Pair.swift
//  FlyingFox
//
//  Created by Simon Whitty on 22/02/2022.
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

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

@testable import FlyingFox

extension Socket {

    static func socketpair(_ domain: Int32, _ type: Int32, _ protocol: Int32) -> (Int32, Int32) {
        var sockets: [Int32] = [-1, -1]
        #if canImport(Darwin)
        _ = Darwin.socketpair(domain, type, `protocol`, &sockets)
        #else
        _ = Glibc.socketpair(domain, type, `protocol`, &sockets)
        #endif
        return (sockets[0], sockets[1])
    }

    static func makeNonBlockingPair() throws -> (Socket, Socket) {
        let (file1, file2) = Socket.socketpair(AF_UNIX, Socket.stream, 0)
        guard file1 > -1, file2 > -1 else {
            throw SocketError.makeFailed("SocketPair")
        }

        let s1 = Socket(file: file1)
        try s1.setFlags(.nonBlocking)

        let s2 = Socket(file: file2)
        try s2.setFlags(.nonBlocking)

        return (s1, s2)
    }
}
