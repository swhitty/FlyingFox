//
//  AsyncSocketTests.swift
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

@testable import FlyingFox
@testable import FlyingSocks
import Foundation

extension AsyncSocket {

    static func make() async throws -> AsyncSocket {
        try await make(pool: .client)
    }

    static func make(pool: some AsyncSocketPool) throws -> AsyncSocket {
        let socket = try Socket(domain: AF_UNIX, type: Socket.stream)
        return try AsyncSocket(socket: socket, pool: pool)
    }

    static func makePair() async throws -> (AsyncSocket, AsyncSocket) {
        try await makePair(pool: .client)
    }

    static func makePair(pool: some AsyncSocketPool) throws -> (AsyncSocket, AsyncSocket) {
        let (file1, file2) = Socket.socketpair(AF_UNIX, Socket.stream, 0)
        guard file1.rawValue > -1, file2.rawValue > -1 else {
            throw SocketError.makeFailed("SocketPair")
        }

        let s1 = try AsyncSocket(socket: Socket(file: file1), pool: pool)
        let s2 = try AsyncSocket(socket: Socket(file: file2), pool: pool)
        return (s1, s2)
    }

    func writeString(_ string: String) async throws {
        try await write(string.data(using: .utf8)!)
    }

    func readString(length: Int) async throws -> String {
        let bytes = try await read(bytes: length)
        guard let string = String(data: Data(bytes), encoding: .utf8) else {
            throw SocketError.makeFailed("Read")
        }
        return string
    }
}
