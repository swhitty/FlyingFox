//
//  IdentifiableContinuation.swift
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

#if compiler(>=6.0)
/// Invokes the passed in closure with an `IdentifableContinuation` for the current task.
///
/// The body of the closure executes synchronously on the calling actor. Once it returns the calling task is suspended.
/// It is possible to immediately resume the task, or escape the continuation in order to complete it afterwards, which
/// will then resume the suspended task.
///
/// You must invoke the continuation's `resume` method exactly once.
/// - Parameters:
///   - function: A string identifying the declaration that is the notional
///     source for the continuation, used to identify the continuation in
///     runtime diagnostics related to misuse of this continuation.
///   - body: A closure that takes a `IdentifiableContinuation` parameter.
///   - handler: Cancellation closure executed when the current Task is cancelled.  Handler is always called _after_ the body closure is compeled.
/// - Returns: The value continuation is resumed with.
@inlinable
package func withIdentifiableContinuation<T>(
  isolation: isolated (any Actor)? = #isolation,
  function: String = #function,
  body: (IdentifiableContinuation<T, Never>) -> Void,
  onCancel handler: @Sendable (IdentifiableContinuation<T, Never>.ID) -> Void
) async -> T {
    let id = IdentifiableContinuation<T, Never>.ID()
    let state = Mutex((isStarted: false, isCancelled: false))
    nonisolated(unsafe) let body = body
    return await withTaskCancellationHandler {
        await withCheckedContinuation(isolation: isolation, function: function) {
            let continuation = IdentifiableContinuation(id: id, continuation: $0)
            body(continuation)
            let sendCancel = state.withLock {
                $0.isStarted = true
                return $0.isCancelled
            }
            if sendCancel {
                handler(id)
            }
        }
    } onCancel: {
        let sendCancel = state.withLock {
            $0.isCancelled = true
            return $0.isStarted
        }
        if sendCancel {
            handler(id)
        }
    }
}

/// Invokes the passed in closure with an `IdentifableContinuation` for the current task.
///
/// The body of the closure executes synchronously on the calling actor. Once it returns the calling task is suspended.
/// It is possible to immediately resume the task, or escape the continuation in order to complete it afterwards, which
/// will then resume the suspended task.
///
/// You must invoke the continuation's `resume` method exactly once.
/// - Parameters:
///   - function: A string identifying the declaration that is the notional
///     source for the continuation, used to identify the continuation in
///     runtime diagnostics related to misuse of this continuation.
///   - body: A closure that takes a `IdentifiableContinuation` parameter.
///   - handler: Cancellation closure executed when the current Task is cancelled.  Handler is always called _after_ the body closure is compeled.
/// - Returns: The value continuation is resumed with.
@inlinable
package func withIdentifiableThrowingContinuation<T>(
  isolation: isolated (any Actor)? = #isolation,
  function: String = #function,
  body: (IdentifiableContinuation<T, any Error>) -> Void,
  onCancel handler: @Sendable (IdentifiableContinuation<T, any Error>.ID) -> Void
) async throws -> T {
    let id = IdentifiableContinuation<T, any Error>.ID()
    let state = Mutex((isStarted: false, isCancelled: false))
    nonisolated(unsafe) let body = body
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation(isolation: isolation, function: function) {
            let continuation = IdentifiableContinuation(id: id, continuation: $0)
            body(continuation)
            let sendCancel = state.withLock {
                $0.isStarted = true
                return $0.isCancelled
            }
            if sendCancel {
                handler(id)
            }
        }
    } onCancel: {
        let sendCancel = state.withLock {
            $0.isCancelled = true
            return $0.isStarted
        }
        if sendCancel {
            handler(id)
        }
    }
}
#else
/// Invokes the passed in closure with an `IdentifableContinuation` for the current task.
///
/// The body of the closure executes synchronously on the calling actor. Once it returns the calling task is suspended.
/// It is possible to immediately resume the task, or escape the continuation in order to complete it afterwards, which
/// will then resume the suspended task.
///
/// You must invoke the continuation's `resume` method exactly once.
/// - Parameters:
///   - isolation: Actor isolation used when executing the body closure.
///   - function: A string identifying the declaration that is the notional
///     source for the continuation, used to identify the continuation in
///     runtime diagnostics related to misuse of this continuation.
///   - body: A closure that takes a `IdentifiableContinuation` parameter.
///   - handler: Cancellation closure executed when the current Task is cancelled.  Handler is always called _after_ the body closure is compeled.
/// - Returns: The value continuation is resumed with.
@_unsafeInheritExecutor
@inlinable
package func withIdentifiableContinuation<T>(
  isolation: isolated some Actor,
  function: String = #function,
  body: (IdentifiableContinuation<T, Never>) -> Void,
  onCancel handler: @Sendable (IdentifiableContinuation<T, Never>.ID) -> Void
) async -> T {
    let id = IdentifiableContinuation<T, Never>.ID()
    let state = Mutex((isStarted: false, isCancelled: false))
    return await withTaskCancellationHandler {
        await withCheckedContinuation(function: function) {
            let continuation = IdentifiableContinuation(id: id, continuation: $0)
            body(continuation)
            let sendCancel = state.withLock {
                $0.isStarted = true
                return $0.isCancelled
            }
            if sendCancel {
                handler(id)
            }
            _ = isolation
        }
    } onCancel: {
        let sendCancel = state.withLock {
            $0.isCancelled = true
            return $0.isStarted
        }
        if sendCancel {
            handler(id)
        }
    }
}

/// Invokes the passed in closure with an `IdentifableContinuation` for the current task.
///
/// The body of the closure executes synchronously on the calling actor. Once it returns the calling task is suspended.
/// It is possible to immediately resume the task, or escape the continuation in order to complete it afterwards, which
/// will then resume the suspended task.
///
/// You must invoke the continuation's `resume` method exactly once.
/// - Parameters:
///   - isolation: Actor isolation used when executing the body closure.
///   - function: A string identifying the declaration that is the notional
///     source for the continuation, used to identify the continuation in
///     runtime diagnostics related to misuse of this continuation.
///   - body: A closure that takes a `IdentifiableContinuation` parameter.
///   - handler: Cancellation closure executed when the current Task is cancelled.  Handler is always called _after_ the body closure is compeled.
/// - Returns: The value continuation is resumed with.
@_unsafeInheritExecutor
@inlinable
package func withIdentifiableThrowingContinuation<T>(
  isolation: isolated some Actor,
  function: String = #function,
  body: (IdentifiableContinuation<T, any Error>) -> Void,
  onCancel handler: @Sendable (IdentifiableContinuation<T, any Error>.ID) -> Void
) async throws -> T {
    let id = IdentifiableContinuation<T, any Error>.ID()
    let state = Mutex((isStarted: false, isCancelled: false))
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation(function: function) {
            let continuation = IdentifiableContinuation(id: id, continuation: $0)
            body(continuation)
            let sendCancel = state.withLock {
                $0.isStarted = true
                return $0.isCancelled
            }
            if sendCancel {
                handler(id)
            }
            _ = isolation
        }
    } onCancel: {
        let sendCancel = state.withLock {
            $0.isCancelled = true
            return $0.isStarted
        }
        if sendCancel {
            handler(id)
        }
    }
}
#endif

@usableFromInline
package struct IdentifiableContinuation<T, E>: Sendable, Identifiable where E: Error {

    @usableFromInline
    package let id: ID

    @usableFromInline
    package final class ID: Hashable, Sendable {

        @usableFromInline
        init() { }

        @usableFromInline
        package func hash(into hasher: inout Hasher) {
            ObjectIdentifier(self).hash(into: &hasher)
        }

        @usableFromInline
        package static func == (lhs: IdentifiableContinuation<T, E>.ID, rhs: IdentifiableContinuation<T, E>.ID) -> Bool {
            lhs === rhs
        }
    }

    @usableFromInline
    init(id: ID, continuation: CheckedContinuation<T, E>) {
        self.id = id
        self.continuation = continuation
    }

    private let continuation: CheckedContinuation<T, E>

#if compiler(>=6.0)
    package func resume(returning value: sending T) {
        continuation.resume(returning: value)
    }

    package func resume(with result: sending Result<T, E>) {
        continuation.resume(with: result)
    }
#else
    package func resume(returning value: T) {
        continuation.resume(returning: value)
    }

    package func resume(with result: Result<T, E>) {
        continuation.resume(with: result)
    }
#endif

    package func resume(throwing error: E) {
        continuation.resume(throwing: error)
    }

    package func resume() where T == () {
        continuation.resume()
    }
}
