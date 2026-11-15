//
//  SocketPool+WaitUntilSuspended.swift
//  FlyingFox
//
//  Created by Simon Whitty on 15/11/2026.
//  Copyright © 2026 Simon Whitty. All rights reserved.
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

@testable import FlyingSocks
import Foundation

/// A pool a test can ask whether a socket's suspension is registered, without knowing its
/// event queue, as with the pool of an `AsyncSocket`.
protocol SuspensionInspectable: AsyncSocketPool {
    func isSuspended(_ socket: Socket) async -> Bool
}

extension SocketPool: SuspensionInspectable {
    func isSuspended(_ socket: Socket) -> Bool {
        !waiting.continuationIDs(for: socket.file).isEmpty
    }
}

extension AsyncSocketPool {

    /// Waits until a suspension of `socket` is registered with the pool and its queue, so a test
    /// can act on the suspended socket. A fixed sleep is not enough when the machine is busy.
    func waitUntilSuspended(_ socket: Socket, timeout: TimeInterval = 5) async throws {
        guard let pool = self as? any SuspensionInspectable else {
            throw SocketError.failed(type: "waitUntilSuspended", errno: 0, message: "unsupported pool \(type(of: self))")
        }
        let deadline = Date().addingTimeInterval(timeout)
        while await !pool.isSuspended(socket) {
            guard Date() < deadline else {
                throw SocketError.makeTaskTimeout(seconds: timeout)
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
    }
}

extension AsyncSocket {

    /// Waits until a read, write or accept on this socket is suspended in its pool.
    func waitUntilSuspended(timeout: TimeInterval = 5) async throws {
        try await pool.waitUntilSuspended(socket, timeout: timeout)
    }
}
