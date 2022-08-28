//
//  Task+Timeout.swift
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

import Foundation

func withThrowingTimeout<T: Sendable>(seconds: TimeInterval, body: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group -> T in
        group.addTask {
            try await body()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        let success = try await group.next()!
        group.cancelAll()
        return success
    }
}

struct TimeoutError: LocalizedError {
    var errorDescription: String? = "Timed out before completion"
}

extension Task where Success: Sendable, Failure == Error {

    // Start a new Task with a timeout.
    init(priority: TaskPriority? = nil, timeout: TimeInterval, operation: @escaping @Sendable () async throws -> Success) {
        self = Task(priority: priority) {
            try await withThrowingTimeout(seconds: timeout, body: operation)
        }
    }
}

extension Task {

    enum CancellationPolicy {
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
            return try await getValue(cancellingAfter: seconds)
        }
    }

    private func getValue(cancellingAfter seconds: TimeInterval) async throws -> Success {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = try await getValue(cancelling: .whenParentIsCancelled)
            }
            group.addTask {
                try await Task<Never, Never>.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            _ = try await group.next()!
            group.cancelAll()
            return try await value
        }
    }
}
