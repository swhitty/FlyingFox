//
//  IdentifiableContinuationTests.swift
//  IdentifiableContinuation
//
//  Created by Simon Whitty on 20/05/2023.
//  Copyright 2023 Simon Whitty
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/swhitty/IdentifiableContinuation
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

final class IdentifiableContinuationAsyncTests: XCTestCase {

    func testResumesWithValue() async {
        let waiter = Waiter<String?, Never>()
        let val = await waiter.identifiableContinuation {
            $0.resume(returning: "Fish")
        }

        XCTAssertEqual(val, "Fish")
    }

    func testResumesWithVoid() async {
        let waiter = Waiter<Void, Never>()
        await waiter.identifiableContinuation {
            $0.resume()
        }
    }

    func testResumesWithResult() async {
        let waiter = Waiter<String?, Never>()
        let val = await waiter.identifiableContinuation {
            $0.resume(with: .success("Chips"))
        }

        XCTAssertEqual(val, "Chips")
    }

    func testCancels_After_Created() async {
        let waiter = Waiter<String?, Never>()

        let task = await waiter.makeTask(onCancel: nil)
        try? await Task.sleep(seconds: 0.1)
        var isEmpty = await waiter.isEmpty
        XCTAssertFalse(isEmpty)
        task.cancel()

        let val = await task.value
        XCTAssertNil(val)

        isEmpty = await waiter.isEmpty
        XCTAssertTrue(isEmpty)
    }

    func testCancels_Before_Created() async {
        let waiter = Waiter<String?, Never>()

        let task = await waiter.makeTask(delay: 1.0, onCancel: nil)
        try? await Task.sleep(seconds: 0.1)
        let isEmpty = await waiter.isEmpty
        XCTAssertTrue(isEmpty)
        task.cancel()

        let val = await task.value
        XCTAssertNil(val)
    }

    func testThrowingResumesWithValue() async {
        let waiter = Waiter<String, any Error>()
        let task = Task {
            try await waiter.throwingIdentifiableContinuation {
                $0.resume(returning: "Fish")
            }
        }

        let result = await task.result
        XCTAssertEqual(try result.get(), "Fish")
    }

    func testThrowingResumesWithError() async {
        let waiter = Waiter<String?, any Error>()
        let task = Task<String, any Error> {
            try await waiter.throwingIdentifiableContinuation {
                $0.resume(throwing: CancellationError())
            }
        }

        let result = await task.result
        XCTAssertThrowsError(try result.get())
    }

    func testThrowingResumesWithResult() async {
        let waiter = Waiter<String?, any Error>()
        let task = Task<String, any Error> {
            try await waiter.throwingIdentifiableContinuation {
                $0.resume(with: .success("Fish"))
            }
        }

        let result = await task.result
        XCTAssertEqual(try result.get(), "Fish")
    }

    func testThrowingCancels_After_Created() async {
        let waiter = Waiter<String?, any Error>()

        let task = await waiter.makeTask(onCancel: .failure(CancellationError()))
        try? await Task.sleep(seconds: 0.1)
        var isEmpty = await waiter.isEmpty
        XCTAssertFalse(isEmpty)
        task.cancel()

        let result = await task.result
        XCTAssertThrowsError(try result.get())

        isEmpty = await waiter.isEmpty
        XCTAssertTrue(isEmpty)
    }

    func testThrowingCancels_Before_Created() async {
        let waiter = Waiter<String?, any Error>()

        let task = await waiter.makeTask(delay: 1.0, onCancel: .failure(CancellationError()))
        try? await Task.sleep(seconds: 0.1)
        let isEmpty = await waiter.isEmpty
        XCTAssertTrue(isEmpty)
        task.cancel()

        let result = await task.result
        XCTAssertThrowsError(try result.get())
    }
}

private actor Waiter<T: Sendable, E: Error> {
    typealias Continuation = IdentifiableContinuation<T, E>

    private var waiting = [Continuation.ID: Continuation]()

    var isEmpty: Bool {
        waiting.isEmpty
    }

    func makeTask(delay: TimeInterval = 0, onCancel: T) -> Task<T, Never> where E == Never {
        Task {
            try? await Task.sleep(seconds: delay)
#if compiler(>=6.0)
            return await withIdentifiableContinuation {
                addContinuation($0)
            } onCancel: { id in
                Task { await self.resumeID(id, returning: onCancel) }
            }
#else
            return await withIdentifiableContinuation(isolation: self) {
                addContinuation($0)
            } onCancel: { id in
                Task { await self.resumeID(id, returning: onCancel) }
            }
#endif
        }
    }

    func makeTask(delay: TimeInterval = 0, onCancel: Result<T, E>) -> Task<T, any Error> where E == any Error {
        Task {
            try? await Task.sleep(seconds: delay)
#if compiler(>=6.0)
            return try await withIdentifiableThrowingContinuation {
                addContinuation($0)
            } onCancel: { id in
                Task { await self.resumeID(id, with: onCancel) }
            }
#else
            return try await withIdentifiableThrowingContinuation(isolation: self) {
                addContinuation($0)
            } onCancel: { id in
                Task { await self.resumeID(id, with: onCancel) }
            }
#endif
        }
    }

    private func addContinuation(_ continuation: Continuation) {
        assertIsolated()
        waiting[continuation.id] = continuation
    }

    private func resumeID(_ id: Continuation.ID, returning value: T) {
        assertIsolated()
        if let continuation = waiting.removeValue(forKey: id) {
            continuation.resume(returning: value)
        }
    }

    private func resumeID(_ id: Continuation.ID, throwing error: E) {
        assertIsolated()
        if let continuation = waiting.removeValue(forKey: id) {
            continuation.resume(throwing: error)
        }
    }

    private func resumeID(_ id: Continuation.ID, with result: Result<T, E>) {
        assertIsolated()
        if let continuation = waiting.removeValue(forKey: id) {
            continuation.resume(with: result)
        }
    }
}

private extension Actor {

    func identifiableContinuation<T: Sendable>(
        body:  @Sendable (IdentifiableContinuation<T, Never>) -> Void,
        onCancel handler: @Sendable (IdentifiableContinuation<T, Never>.ID) -> Void = { _ in }
    ) async -> T {
#if compiler(>=6.0)
        await withIdentifiableContinuation(body: body, onCancel: handler)
#else
        await withIdentifiableContinuation(isolation: self, body: body, onCancel: handler)
#endif
    }

    func throwingIdentifiableContinuation<T: Sendable>(
        body:  @Sendable (IdentifiableContinuation<T, any Error>) -> Void,
        onCancel handler: @Sendable (IdentifiableContinuation<T, any Error>.ID) -> Void = { _ in }
    ) async throws -> T {
#if compiler(>=6.0)
        try await withIdentifiableThrowingContinuation(body: body, onCancel: handler)
#else
        try await withIdentifiableThrowingContinuation(isolation: self, body: body, onCancel: handler)
#endif

    }
}
