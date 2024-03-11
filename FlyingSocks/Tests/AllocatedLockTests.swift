//
//  AllocatedLockTests.swift
//  AllocatedLock
//
//  Created by Simon Whitty on 10/04/2023.
//  Copyright 2023 Simon Whitty
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/swhitty/AllocatedLock
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

@_spi(Private) import struct FlyingSocks.AllocatedLock
import XCTest

final class AllocatedLockTests: XCTestCase {

    func testLockState_IsProtected() async {
        let state = AllocatedLock<Int>(initialState: 0)

        let total = await withTaskGroup(of: Void.self) { group in
            for i in 1...1000 {
                group.addTask {
                    state.withLock { $0 += i }
                }
            }
            await group.waitForAll()
            return state.withLock { $0 }
        }

        XCTAssertEqual(total, 500500)
    }

    func testLock_ReturnsValue() async {
        let lock = AllocatedLock()
        let value = lock.withLock { true }
        XCTAssertTrue(value)
    }

    func testLock_Blocks() async {
        let lock = AllocatedLock()

        Task { @MainActor in
            lock.unsafeLock()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            lock.unsafeUnlock()
        }

        try? await Task.sleep(nanoseconds: 500_000)

        let results = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                try? await Task.sleep(nanoseconds: 5_000_000)
                return true
            }
            group.addTask {
                lock.unsafeLock()
                lock.unsafeUnlock()
                return false
            }
            let first = await group.next()!
            let second = await group.next()!
            return [first, second]
        }
        XCTAssertEqual(results, [true, false])
    }
}

// sidestep warning: unavailable from asynchronous contexts
extension AllocatedLock where State == Void {
    func unsafeLock() { lock() }
    func unsafeUnlock() { unlock() }
}
