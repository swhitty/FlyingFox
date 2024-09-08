//
//  MutexTests.swift
//  swift-mutex
//
//  Created by Simon Whitty on 07/09/2024.
//  Copyright 2024 Simon Whitty
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/swhitty/swift-mutex
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
import XCTest

final class MutexTests: XCTestCase {

    func testWithLock_ReturnsValue() {
        let mutex = Mutex("fish")
        let val = mutex.withLock {
            $0 + " & chips"
        }
        XCTAssertEqual(val, "fish & chips")
    }

    func testWithLock_ThrowsError() {
        let mutex = Mutex("fish")
        XCTAssertThrowsError(try mutex.withLock { _ -> Void in throw CancellationError() }) {
            _ = $0 is CancellationError
        }
    }

    func testLockIfAvailable_ReturnsValue() {
        let mutex = Mutex("fish")
        mutex.storage.lock()
        XCTAssertNil(
            mutex.withLockIfAvailable { _ in "chips" }
        )
        mutex.storage.unlock()
        XCTAssertEqual(
            mutex.withLockIfAvailable { _ in "chips" },
            "chips"
        )
    }

    func testWithLockIfAvailable_ThrowsError() {
        let mutex = Mutex("fish")
        XCTAssertThrowsError(try mutex.withLockIfAvailable { _ -> Void in throw CancellationError() }) {
            _ = $0 is CancellationError
        }
    }
}
