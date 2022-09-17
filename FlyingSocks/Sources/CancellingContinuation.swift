//
//  CancellingContinuation.swift
//  FlyingFox
//
//  Created by Simon Whitty on 27/08/2022.
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

/// Wrapper around `CheckedContinuation` throwing CancellationError when the
/// task is cancelled.
public struct CancellingContinuation<Success, Failure: Error>: Sendable {

    let inner: Inner

    public init() {
        self.inner = Inner()
    }

    public var value: Success {
        get async throws {
            try await withTaskCancellationHandler {
                try await inner.getValue()
            } onCancel: {
                cancel()
            }
        }
    }

    public func resume(returning value: Success) {
        Task { await inner.resume(with: .success(value)) }
    }

    public func resume() where Success == Void {
        resume(returning: ())
    }

    public func resume(throwing error: Failure) {
        Task { await inner.resume(with: .failure(error)) }
    }

    public func resume(with result: Result<Success, Failure>) {
        Task { await inner.resume(with: result.mapError { $0 as Error }) }
    }

    public func cancel() {
        Task { await inner.resume(with: .failure(CancellationError())) }
    }
}

extension CancellingContinuation {

    actor Inner {
        private var continuation: UnsafeContinuation<Success, Error>?
        private var result: Result<Success, Error>?
        private var hasStarted: Bool = false

        func getValue() async throws -> Success {
            precondition(hasStarted == false, "Can only wait a single time.")
            hasStarted = true
            guard let result = result else {
                return try await withUnsafeThrowingContinuation {
                    continuation = $0
                }
            }
            return try result.get()
        }

        func resume(with result: Result<Success, Error>) {
            if let continuation = continuation {
                self.continuation = nil
                continuation.resume(with: result)
            } else if self.result == nil {
                self.result = result
            }
        }
    }
}

extension CancellingContinuation: Hashable {
    public static func == (lhs: CancellingContinuation<Success, Failure>, rhs: CancellingContinuation<Success, Failure>) -> Bool {
        lhs.inner === rhs.inner
    }

    public func hash(into hasher: inout Hasher) {
        ObjectIdentifier(inner).hash(into: &hasher)
    }
}
