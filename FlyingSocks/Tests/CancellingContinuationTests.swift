//
//  CancellingContinuationTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 28/08/2022.
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

import FlyingSocks
import XCTest

final class CancellingContinuationTests: XCTestCase {

    func testContinuationHashable() {
        let continuation = CancellingContinuation<String, Never>()
        let other = CancellingContinuation<String, Never>()

        var continuations = Set([continuation])

        XCTAssertTrue(continuations.contains(continuation))
        XCTAssertFalse(continuations.contains(other))

        continuations.insert(other)
        XCTAssertTrue(continuations.contains(continuation))
        XCTAssertTrue(continuations.contains(other))

        continuations.remove(continuation)
        XCTAssertFalse(continuations.contains(continuation))
        XCTAssertTrue(continuations.contains(other))
    }

    func testEarlyResultIsReturned() async {
        let continuation = CancellingContinuation<String, Never>()

        continuation.resume(returning: "Fish")
        let task = Task { try await continuation.value }
        task.cancel()

        await AsyncAssertEqual(
            try await task.value,
            "Fish"
        )
    }

    func testCancellationIsReturned() async {
        let continuation = CancellingContinuation<String, Never>()

        let task = Task { try await continuation.value }
        task.cancel()

        await AsyncAssertThrowsError(
            try await task.value,
            of: CancellationError.self
        )
    }

    func testResumeIsReturned() async {
        let continuation = CancellingContinuation<Void, Error>()

        let task = Task { try await continuation.value }
        continuation.resume()

        let result = await task.result
        XCTAssertNoThrow(try result.get())
    }

    func testErrorIsReturned() async {
        let continuation = CancellingContinuation<String, Error>()

        let task = Task { try await continuation.value }
        continuation.resume(throwing: SocketError.disconnected)

        await AsyncAssertThrowsError(
            try await task.value,
            of: SocketError.self
        )
    }

    func testResultIsReturned() async {
        let continuation = CancellingContinuation<String, SocketError>()

        let task = Task { try await continuation.value }
        continuation.resume(with: .failure(.disconnected))

        await AsyncAssertThrowsError(
            try await task.value,
            of: SocketError.self
        )
    }
}
