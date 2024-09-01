//
//  TaskTimeout.swift
//  TaskTimeout
//
//  Created by Simon Whitty on 31/08/2024.
//  Copyright 2024 Simon Whitty
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/swhitty/TaskTimeout
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

import Foundation

package struct TimeoutError: LocalizedError {
    package var errorDescription: String?

    package init(timeout: TimeInterval) {
        self.errorDescription = "Task timed out before completion. Timeout: \(timeout) seconds."
    }
}

#if compiler(>=6.0)
package func withThrowingTimeout<T>(
    isolation: isolated (any Actor)? = #isolation,
    seconds: TimeInterval,
    body: () async throws -> sending T
) async throws -> sending T {
    let transferringBody = { try await Transferring(body()) }
    typealias NonSendableClosure = () async throws -> Transferring<T>
    typealias SendableClosure = @Sendable () async throws -> Transferring<T>
    return try await withoutActuallyEscaping(transferringBody) {
        (_ fn: @escaping NonSendableClosure) async throws -> Transferring<T> in
        let sendableFn = unsafeBitCast(fn, to: SendableClosure.self)
        return try await _withThrowingTimeout(isolation: isolation, seconds: seconds, body: sendableFn)
    }.value
}

// Sendable
private func _withThrowingTimeout<T: Sendable>(
    isolation: isolated (any Actor)? = #isolation,
    seconds: TimeInterval,
    body: @Sendable @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await body()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError(timeout: seconds)
        }
        let success = try await group.next()!
        group.cancelAll()
        return success
    }
}
#else
package func withThrowingTimeout<T>(
    seconds: TimeInterval,
    body: () async throws -> T
) async throws -> T {
    let transferringBody = { try await Transferring(body()) }
    typealias NonSendableClosure = () async throws -> Transferring<T>
    typealias SendableClosure = @Sendable () async throws -> Transferring<T>
    return try await withoutActuallyEscaping(transferringBody) {
        (_ fn: @escaping NonSendableClosure) async throws -> Transferring<T> in
        let sendableFn = unsafeBitCast(fn, to: SendableClosure.self)
        return try await _withThrowingTimeout(seconds: seconds, body: sendableFn)
    }.value
}

// Sendable
private func _withThrowingTimeout<T: Sendable>(
    seconds: TimeInterval,
    body: @Sendable @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await body()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError(timeout: seconds)
        }
        let success = try await group.next()!
        group.cancelAll()
        return success
    }
}
#endif

package extension Task {

    enum CancellationPolicy: Sendable {
        /// Cancels the task when the task retrieving the value is cancelled
        case whenParentIsCancelled

        /// Cancels the task after a timeout elapses
        case afterTimeout(seconds: TimeInterval)
    }

    /// Waits for the task to complete, cancelling the task according to the provided policy
    /// - Parameter policy: Policy that defines how the task should be cancelled.
    /// - Returns: The task value
    func getValue(cancelling policy: CancellationPolicy) async throws -> Success {
        switch policy {
        case .whenParentIsCancelled:
            return try await withTaskCancellationHandler {
                try await value
            } onCancel: {
                cancel()
            }
        case .afterTimeout(let seconds):
            if seconds > 0 {
                return try await getValue(cancellingAfter: seconds)
            } else {
                cancel()
                return try await value
            }
        }
    }

    private func getValue(cancellingAfter seconds: TimeInterval) async throws -> Success {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = try await getValue(cancelling: .whenParentIsCancelled)
            }
            group.addTask {
                try await Task<Never, Never>.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError(timeout: seconds)
            }
            _ = try await group.next()!
            group.cancelAll()
            return try await value
        }
    }
}
