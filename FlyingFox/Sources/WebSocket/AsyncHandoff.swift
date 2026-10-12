//
//  AsyncHandoff.swift
//  FlyingFox
//
//  Created by Luke Howard on 12/10/2026.
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

import FlyingSocks

/// Passes elements from one task to another, one at a time. `send(_:)` suspends
/// until `next()` takes the element, so a sender gets no further ahead than its
/// receiver and nothing is buffered between them.
actor AsyncHandoff<Element: Sendable> {

    private typealias Sender = (element: Element, continuation: IdentifiableContinuation<Void, any Error>)
    private typealias Receiver = IdentifiableContinuation<Element?, any Error>

    private var senders = [Sender]()
    private var receivers = [Receiver]()
    private var isFinished = false
    private var result: Result<Element?, any Error> = .success(nil)

    /// Hands `element` to the receiver, suspending until it is taken.
    /// Throws `CancellationError` if cancelled or finished before then.
    func send(_ element: Element) async throws {
        guard !isFinished else {
            throw CancellationError()
        }
        if !receivers.isEmpty {
            receivers.removeFirst().resume(returning: element)
            return
        }
        try await withIdentifiableThrowingContinuation(isolation: self) {
            senders.append((element, $0))
        } onCancel: { id in
            Task { await self.cancelSender(id: id) }
        }
    }

    /// Takes the next element, suspending until one is sent. Once finished,
    /// returns the final element or error, then nil. Returns nil if cancelled.
    func next() async throws -> Element? {
        if !senders.isEmpty {
            let sender = senders.removeFirst()
            sender.continuation.resume()
            return sender.element
        }
        if isFinished {
            defer { result = .success(nil) }
            return try result.get()
        }
        return try await withIdentifiableThrowingContinuation(isolation: self) {
            receivers.append($0)
        } onCancel: { id in
            Task { await self.cancelReceiver(id: id) }
        }
    }

    /// Ends the handoff. The receiver gets `result`, a last element or an error,
    /// before nil; senders still waiting are cancelled.
    func finish(with result: Result<Element?, any Error> = .success(nil)) {
        guard !isFinished else { return }
        isFinished = true
        self.result = result
        for sender in senders {
            sender.continuation.resume(throwing: CancellationError())
        }
        senders = []
        if !receivers.isEmpty {
            receivers.removeFirst().resume(with: result)
            self.result = .success(nil)
        }
        for receiver in receivers {
            receiver.resume(returning: nil)
        }
        receivers = []
    }

    func finish(throwing error: any Error) {
        finish(with: .failure(error))
    }

    private func cancelSender(id: IdentifiableContinuation<Void, any Error>.ID) {
        guard let index = senders.firstIndex(where: { $0.continuation.id == id }) else { return }
        senders.remove(at: index).continuation.resume(throwing: CancellationError())
    }

    private func cancelReceiver(id: Receiver.ID) {
        guard let index = receivers.firstIndex(where: { $0.id == id }) else { return }
        receivers.remove(at: index).resume(returning: nil)
    }
}
