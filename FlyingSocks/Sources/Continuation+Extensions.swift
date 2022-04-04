//
//  Continuation+Extensions.swift
//  FlyingFox
//
//  Created by Simon Whitty on 17/02/2022.
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

func withCancellingContinuation<T>(function: String = #function,
                                   returning returnType: T.Type,
                                   body: (CheckedContinuation<T, Error>, inout CancellationHandler) -> Void) async throws -> T {
    let inner = CancellationHandler.Inner()
    return try await withTaskCancellationHandler(
        operation: {
            try await withCheckedThrowingContinuation(function: function) { (continuation: CheckedContinuation<T, Error>) in
                var handler = CancellationHandler(inner: inner)
                body(continuation, &handler)
            }
        },
        onCancel: inner.cancel)
}

struct CancellationHandler {

    fileprivate let inner: Inner

    @Sendable
    mutating func onCancel(_ handler: @escaping () -> Void) {
        inner.onCancel(handler)
    }
}

extension CancellationHandler {

    final class Inner {

        private let lock = NSLock()
        private var isCancelled: Bool = false
        private var handler: (() -> Void)?

        @Sendable
        func onCancel(_ handler: @escaping () -> Void) {
            lock.lock()
            self.handler = handler
            let isCancelled = self.isCancelled
            lock.unlock()

            if isCancelled {
                handler()
            }
        }

        @Sendable
        fileprivate func cancel() {
            lock.lock()
            isCancelled = true
            let handler = self.handler
            lock.unlock()

            handler?()
        }
    }
}



