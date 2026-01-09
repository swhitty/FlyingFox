//
//  TaskTimeout.swift
//  swift-timeout
//
//  Created by Simon Whitty on 31/08/2024.
//  Copyright 2024 Simon Whitty
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/swhitty/swift-timeout
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

@available(*, unavailable, renamed: "SocketError.timeout")
public typealias TimeoutError = SocketError

package func withThrowingTimeout<T>(
    isolation: isolated (any Actor)? = #isolation,
    seconds: TimeInterval,
    body: () async throws -> sending T
) async throws -> sending T {
    try await withoutActuallyEscaping(body) { escapingBody in
        let bodyTask = Task {
            defer { _ = isolation }
            return try await Transferring(escapingBody())
        }
        let timeoutTask = Task {
            defer { bodyTask.cancel() }
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw SocketError.makeTaskTimeout(seconds: seconds)
        }

        let bodyResult = await withTaskCancellationHandler {
            await bodyTask.result
        } onCancel: {
            bodyTask.cancel()
        }
        timeoutTask.cancel()

        if case let .failure(SocketError.timeout(message: message)) = await timeoutTask.result {
            throw SocketError.timeout(message: message)
        } else {
            return try bodyResult.get()
        }
    }.value
}

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
                return try await withThrowingTimeout(seconds: seconds) {
                    try await getValue(cancelling: .whenParentIsCancelled)
                }
            } else {
                cancel()
                return try await value
            }
        }
    }
}

package extension SocketError {
    static func makeTaskTimeout(seconds timeout: TimeInterval) -> SocketError {
        .timeout(message: "Task timed out before completion. Timeout: \(timeout) seconds.")
    }
}
