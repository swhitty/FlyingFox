//
//  AsyncBufferedEmptySequence.swift
//  FlyingFox
//
//  Created by Simon Whitty on 06/08/2024.
//  Copyright © 2024 Simon Whitty. All rights reserved.
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

package struct AsyncBufferedEmptySequence<Element: Sendable>: Sendable, AsyncBufferedSequence {

    private let completeImmediately: Bool

    package init(completeImmediately: Bool = false) {
        self.completeImmediately = completeImmediately
    }

    package func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(completeImmediately: completeImmediately)
    }

    package struct AsyncIterator: AsyncBufferedIteratorProtocol {
        let completeImmediately: Bool

        package mutating func next() async -> Element? {
            if completeImmediately {
                return nil
            }
            let state = Mutex(State())
            return await withTaskCancellationHandler {
                await withCheckedContinuation { (continuation: CheckedContinuation<Element?, Never>) in
                    let shouldCancel = state.withLock {
                        $0.continuation = continuation
                        return $0.isCancelled
                    }

                    if shouldCancel {
                        continuation.resume(returning: nil)
                    }
                }
            } onCancel: {
                let continuation = state.withLock {
                    $0.isCancelled = true
                    return $0.continuation
                }
                continuation?.resume(returning: nil)
            }
        }

        package mutating func nextBuffer(suggested count: Int) async -> [Element]? {
            await next().map { [$0] }
        }

        private struct State {
            var continuation: CheckedContinuation<Element?, Never>?
            var isCancelled: Bool = false
        }
    }
}
