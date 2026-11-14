//
//  withDeadline.swift
//  FlyingFox
//
//  Created by Simon Whitty on 14/11/2026.
//  Copyright © 2026 Simon Whitty. All rights reserved.
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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// A backport of `withDeadline` from SE-0526, which is coming to the Concurrency module:
// https://github.com/swiftlang/swift-evolution/blob/main/proposals/0526-deadline.md
//
// Like the proposal, when the deadline expires the body is cancelled, and `withDeadline`
// returns or throws whatever the body does in response. There is no timeout error: a body
// that stops when cancelled typically throws `CancellationError`.
//
// Differences from the proposal, needed to build with Swift 6.0 and the package's
// deployment targets:
// - The body runs in a child task inheriting the caller's isolation, which is what gets
//   cancelled. The proposal runs it inline using `nonisolated(nonsending)` (Swift 6.2) and
//   runtime support that cancels only the body.
// - `isolation: isolated (any Actor)? = #isolation` stands in for `nonisolated(nonsending)`.
// - Untyped `throws`, and a Copyable `Return`, because a Task's result must be Copyable and
//   its failure `any Error`.
// - No `CancellationError.Reason`, and `Clock` instead of `Clock & Identifiable`.
// - `withDeadline(in: TimeInterval)` for platforms older than `Clock` and `Duration`.
//
// Replace these with the standard library's `withDeadline` once the minimum supported Swift
// version and deployment targets include it.

/// Runs `body`, cancelling it if it hasn't completed by `expiration`.
///
/// Waits for `body` to return after cancelling it, so this can run past the deadline
/// if `body` doesn't respond to cancellation promptly.
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
package func withDeadline<Return, C: Clock>(
    _ expiration: C.Instant,
    tolerance: C.Instant.Duration? = nil,
    clock: C,
    isolation: isolated (any Actor)? = #isolation,
    body: () async throws -> sending Return
) async throws -> sending Return {
    try await withDeadline(
        isolation: isolation,
        sleep: { try await clock.sleep(until: expiration, tolerance: tolerance) },
        body: body
    ).value
}

/// Runs `body`, cancelling it if it hasn't completed within `timeout`.
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
package func withDeadline<Return>(
    in timeout: Duration,
    tolerance: Duration? = nil,
    isolation: isolated (any Actor)? = #isolation,
    body: () async throws -> sending Return
) async throws -> sending Return {
    let clock = ContinuousClock()
    let expiration = clock.now.advanced(by: timeout)
    return try await withDeadline(
        isolation: isolation,
        sleep: { try await clock.sleep(until: expiration, tolerance: tolerance) },
        body: body
    ).value
}

/// Runs `body`, cancelling it if it hasn't completed within `timeout` seconds.
///
/// Available on platforms older than `Clock` and `Duration`. With the standard library's
/// `withDeadline`, use `withDeadline(in: .seconds(timeout))`.
package func withDeadline<Return>(
    in timeout: TimeInterval,
    isolation: isolated (any Actor)? = #isolation,
    body: () async throws -> sending Return
) async throws -> sending Return {
    let nanoseconds = UInt64(Swift.max(0, timeout) * 1_000_000_000)
    return try await withDeadline(
        isolation: isolation,
        sleep: { try await Task.sleep(nanoseconds: nanoseconds) },
        body: body
    ).value
}

// Returns the result boxed: Swift 6.0 doesn't treat a `sending` result forwarded through
// another function as disconnected, but does when it's unboxed by the caller.
private func withDeadline<Return>(
    isolation: isolated (any Actor)?,
    sleep: @escaping @Sendable () async throws -> Void,
    body: () async throws -> sending Return
) async throws -> UncheckedSendable<Return> {
    try await withoutActuallyEscaping(body) { escapingBody in
        let bodyTask = Task {
            // capturing `isolation` runs the body on the caller's actor
            defer { _ = isolation }
            return try await UncheckedSendable(escapingBody())
        }
        let deadlineTask = Task {
            try await sleep()
            bodyTask.cancel()
        }
        let result = await withTaskCancellationHandler {
            await bodyTask.result
        } onCancel: {
            bodyTask.cancel()
        }
        // wait for the deadline task to end too, so no task outlives the call
        deadlineTask.cancel()
        _ = await deadlineTask.result
        return try result.get()
    }
}

// Carries the body's `sending` result out of `bodyTask`. A Task's result must be
// Copyable, so `Disconnected` (which is ~Copyable) can't be used here; the value is
// read exactly once, by the caller that receives it as `sending`.
private struct UncheckedSendable<Value>: @unchecked Sendable {
    var value: Value

    init(_ value: consuming sending Value) {
        self.value = value
    }
}
