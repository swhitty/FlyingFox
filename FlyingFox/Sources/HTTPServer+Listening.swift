//
//  HTTPServer.swift
//  FlyingFox
//
//  Created by Simon Whitty on 13/02/2022.
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

extension HTTPServer {

    public func waitUntilListening(timeout: TimeInterval = 5) async throws {
        try await withThrowingTimeout(seconds: timeout) {
            try await self.doWaitUntilListening()
        }
    }

    private func doWaitUntilListening() async throws {
        guard !isListening else { return }
        try await withCancellingContinuation(returning: Void.self) { c, handler in
            let continuation = Continuation(c)
            waiting.insert(continuation)
            handler.onCancel {
                self.cancelContinuation(continuation)
            }
        }
    }

    // Careful not to escape non-isolated method
    // https://bugs.swift.org/browse/SR-15745
    nonisolated private func cancelContinuation(_ continuation: Continuation) {
        Task { await _cancelContinuation(continuation) }
    }

    private func _cancelContinuation(_ continuation: Continuation) {
        guard let removed = waiting.remove(continuation) else { return }
        removed.cancel()
    }

    func isListeningDidUpdate(from previous: Bool) {
        guard isListening else { return }
        let waiting = self.waiting
        self.waiting = []

        for continuation in waiting {
            continuation.resume()
        }
    }

    final class Continuation: Hashable {

        private let continuation: CheckedContinuation<Void, Swift.Error>

        init(_ continuation: CheckedContinuation<Void, Swift.Error>) {
            self.continuation = continuation
        }

        func resume() {
            continuation.resume()
        }

        func cancel() {
            continuation.resume(throwing: CancellationError())
        }

        func hash(into hasher: inout Hasher) {
            ObjectIdentifier(self).hash(into: &hasher)
        }

        static func == (lhs: Continuation, rhs: Continuation) -> Bool {
            lhs === rhs
        }
    }
}
