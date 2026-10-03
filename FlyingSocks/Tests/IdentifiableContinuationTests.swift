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
import Foundation
import Testing

struct IdentifiableContinuationAsyncTests {

    @Test
    func resumesWithValue() async {
        let waiter = Waiter<String?, Never>()
        let val = await waiter.identifiableContinuation {
            $0.resume(returning: "Fish")
        }

        #expect(val == "Fish")
    }

    @Test
    func resumesWithVoid() async {
        let waiter = Waiter<Void, Never>()
        await waiter.identifiableContinuation {
            $0.resume()
        }
    }

    @Test
    func resumesWithResult() async {
        let waiter = Waiter<String?, Never>()
        let val = await waiter.identifiableContinuation {
            $0.resume(with: .success("Chips"))
        }

        #expect(val == "Chips")
    }

    @Test
    func cancels_After_Created() async {
        let waiter = Waiter<String?, Never>()

        let task = await waiter.makeTask(onCancel: nil)
        await waiter.waitUntilCreated()
        var isEmpty = await waiter.isEmpty
        #expect(!isEmpty)
        task.cancel()

        let val = await task.value
        #expect(val == nil)

        isEmpty = await waiter.isEmpty
        #expect(isEmpty)
    }

    @Test
    func cancels_Before_Created() async {
        let waiter = Waiter<String?, Never>()

        let task = await waiter.makeTask(pauseBeforeCreating: true, onCancel: nil)
        await waiter.waitUntilPaused()
        let isEmpty = await waiter.isEmpty
        #expect(isEmpty)
        task.cancel()
        await waiter.resumeCreation()

        let val = await task.value
        #expect(val == nil)
    }

    @Test
    func throwingResumesWithValue() async throws {
        let waiter = Waiter<String, any Error>()
        let task = Task {
            try await waiter.throwingIdentifiableContinuation {
                $0.resume(returning: "Fish")
            }
        }

        let result = await task.result
        #expect(try result.get() == "Fish")
    }

    @Test
    func throwingResumesWithError() async {
        let waiter = Waiter<String?, any Error>()
        let task = Task<String, any Error> {
            try await waiter.throwingIdentifiableContinuation {
                $0.resume(throwing: CancellationError())
            }
        }

        let result = await task.result
        #expect(throws: CancellationError.self) {
            try result.get()
        }
    }

    @Test
    func throwingResumesWithResult() async throws {
        let waiter = Waiter<String?, any Error>()
        let task = Task<String, any Error> {
            try await waiter.throwingIdentifiableContinuation {
                $0.resume(with: .success("Fish"))
            }
        }

        let result = await task.result
        #expect(try result.get() == "Fish")
    }

    @Test
    func throwingCancels_After_Created() async {
        let waiter = Waiter<String?, any Error>()

        let task = await waiter.makeTask(onCancel: .failure(CancellationError()))
        await waiter.waitUntilCreated()
        var isEmpty = await waiter.isEmpty
        #expect(!isEmpty)
        task.cancel()

        let result = await task.result
        #expect(throws: CancellationError.self) {
            try result.get()
        }

        isEmpty = await waiter.isEmpty
        #expect(isEmpty)
    }

    @Test
    func throwingCancels_Before_Created() async {
        let waiter = Waiter<String?, any Error>()

        let task = await waiter.makeTask(pauseBeforeCreating: true, onCancel: .failure(CancellationError()))
        await waiter.waitUntilPaused()
        let isEmpty = await waiter.isEmpty
        #expect(isEmpty)
        task.cancel()
        await waiter.resumeCreation()

        let result = await task.result
        #expect(throws: CancellationError.self) {
            try result.get()
        }
    }
}

private actor Waiter<T: Sendable, E: Error> {
    typealias Continuation = IdentifiableContinuation<T, E>

    private var waiting = [Continuation.ID: Continuation]()
    private var creationObserver: CheckedContinuation<Void, Never>?
    private var pauseObserver: CheckedContinuation<Void, Never>?
    private var creationGate: CheckedContinuation<Void, Never>?

    var isEmpty: Bool {
        waiting.isEmpty
    }

    func makeTask(pauseBeforeCreating: Bool = false, onCancel: T) -> Task<T, Never> where E == Never {
        Task {
            if pauseBeforeCreating {
                await pauseCreation()
            }
            return await withIdentifiableContinuation {
                addContinuation($0)
            } onCancel: { id in
                Task { await self.resumeID(id, returning: onCancel) }
            }
        }
    }

    func makeTask(pauseBeforeCreating: Bool = false, onCancel: Result<T, E>) -> Task<T, any Error> where E == any Error {
        Task {
            if pauseBeforeCreating {
                await pauseCreation()
            }
            return try await withIdentifiableThrowingContinuation {
                addContinuation($0)
            } onCancel: { id in
                Task { await self.resumeID(id, with: onCancel) }
            }
        }
    }

    func waitUntilCreated() async {
        guard waiting.isEmpty else { return }
        await withCheckedContinuation {
            creationObserver = $0
        }
    }

    func waitUntilPaused() async {
        guard creationGate == nil else { return }
        await withCheckedContinuation {
            pauseObserver = $0
        }
    }

    func resumeCreation() {
        creationGate?.resume()
        creationGate = nil
    }

    private func pauseCreation() async {
        // Cancellation must not release this gate: the before-creation tests resume
        // the already-cancelled task so it still invokes the continuation API.
        await withCheckedContinuation {
            creationGate = $0
            pauseObserver?.resume()
            pauseObserver = nil
        }
    }

    private func addContinuation(_ continuation: Continuation) {
        assertIsolated()
        waiting[continuation.id] = continuation
        creationObserver?.resume()
        creationObserver = nil
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
        await withIdentifiableContinuation(body: body, onCancel: handler)
    }

    func throwingIdentifiableContinuation<T: Sendable>(
        body:  @Sendable (IdentifiableContinuation<T, any Error>) -> Void,
        onCancel handler: @Sendable (IdentifiableContinuation<T, any Error>.ID) -> Void = { _ in }
    ) async throws -> T {
        try await withIdentifiableThrowingContinuation(body: body, onCancel: handler)

    }
}
