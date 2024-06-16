//
//  Task+TimeoutTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 15/02/2022.
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

@testable import FlyingSocks
import Foundation
import Testing

struct TaskTimeoutTests {

    @Test func testTimeoutReturnsSuccess_WhenTimeoutDoesNotExpire() async throws {
        // given
        let value = try await Task(timeout: 0.5) {
            "Fish"
        }.value

        // then
        #expect(value == "Fish")
    }

    @Test func testTimeoutThrowsError_WhenTimeoutExpires() async {
        // given
        let task = Task<Void, any Error>(timeout: 0.5) {
            try? await Task.sleep(seconds: 10)
        }

        // then
        await #expect(throws: TimeoutError.self) {
            _ = try await task.value
        }
    }

    @Test func testTimeoutCancels() async {
        // given
        let task = Task(timeout: 0.5) {
            try await Task.sleep(seconds: 10)
        }

        // when
        task.cancel()

        // then
        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }

    @Test func testTaskTimeoutParentThrowsError() async {
        let task = Task {
            try await Task.sleep(seconds: 10)
        }

        let parent = Task {
            try await task.getValue(cancelling: .whenParentIsCancelled)
        }

        parent.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await parent.value
        }
    }

    @Test func testTaskTimeoutZeroThrowsError() async throws {
        let task = Task {
            try await Task.sleep(seconds: 10)
        }

        await #expect(throws: CancellationError.self) {
            try await task.getValue(cancelling: .afterTimeout(seconds: 0))
        }
    }

    @Test func testTaskTimeoutThrowsError() async throws {
        let task = Task {
            try await Task.sleep(seconds: 10)
        }

        await #expect(throws: TimeoutError.self) {
            try await task.getValue(cancelling: .afterTimeout(seconds: 0.1))
        }
    }

    @Test func testTaskTimeoutParentReturnsSuccess() async throws {
        let task = Task { "Fish" }

        #expect(
            try await task.getValue(cancelling: .whenParentIsCancelled) == "Fish"
        )
    }

    @Test func testTaskTimeoutZeroReturnsSuccess() async throws {
        let task = Task { "Fish" }

        #expect(
            try await task.getValue(cancelling: .afterTimeout(seconds: 0)) == "Fish"
        )
    }

    @Test func testTaskTimeoutReturnsSuccess() async throws {
        let task = Task { "Fish" }

        #expect(
            try await task.getValue(cancelling: .afterTimeout(seconds: 0.1)) == "Fish"
        )
    }
}

@_spi(Private) import func FlyingSocks.withThrowingTimeout

extension Task where Success: Sendable, Failure == any Error {

    // Start a new Task with a timeout.
    init(priority: TaskPriority? = nil, timeout: TimeInterval, operation: @escaping @Sendable () async throws -> Success) {
        self = Task(priority: priority) {
            try await withThrowingTimeout(seconds: timeout, body: operation)
        }
    }
}

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: TimeInterval) async throws {
        try await sleep(nanoseconds: UInt64(1_000_000_000 * seconds))
    }
}
