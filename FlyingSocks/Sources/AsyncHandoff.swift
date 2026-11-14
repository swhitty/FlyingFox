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

/// Passes elements from one task to another in order, holding at most `capacity`
/// of them. `send(_:)` suspends while the buffer is full, so a sender gets no
/// further ahead than `capacity` elements of its receiver. With a capacity of 0,
/// `send(_:)` suspends until `next()` returns the element and nothing is buffered.
package actor AsyncHandoff<Element: Sendable> {

    private typealias Sender = (element: Element, continuation: IdentifiableContinuation<Void, any Error>)
    private typealias Receiver = IdentifiableContinuation<Element?, any Error>

    private let capacity: Int
    private var buffer = [Element]()
    private var senders = [Sender]()
    private var receivers = [Receiver]()
    private var isFinished = false
    private var result: Result<Element?, any Error> = .success(nil)

    package init(capacity: Int = 0) {
        precondition(capacity >= 0, "capacity must not be negative")
        self.capacity = capacity
    }

    /// Hands `element` to the receiver, suspending until it is received or buffered.
    /// Throws `AsyncHandoffFinishedError` if the handoff is finished before then,
    /// or `CancellationError` if the sending task is cancelled.
    package func send(_ element: Element) async throws {
        guard !isFinished else {
            throw AsyncHandoffFinishedError()
        }
        if !receivers.isEmpty {
            receivers.removeFirst().resume(returning: element)
            return
        }
        if buffer.count < capacity {
            buffer.append(element)
            return
        }
        try await withIdentifiableThrowingContinuation(isolation: self) {
            senders.append((element, $0))
        } onCancel: { id in
            Task { await self.cancelSender(id: id) }
        }
    }

    /// Returns the next element, suspending until one is sent. Once finished,
    /// returns the buffered elements, the final element or error, then nil.
    /// Returns nil if cancelled.
    package func next() async throws -> Element? {
        if !buffer.isEmpty {
            let element = buffer.removeFirst()
            admitSender()
            return element
        }
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

    /// Ends the handoff. The receiver gets the buffered elements and `result`, a last
    /// element or an error, before nil; senders still waiting throw `AsyncHandoffFinishedError`.
    package func finish(with result: Result<Element?, any Error> = .success(nil)) {
        guard !isFinished else { return }
        isFinished = true
        self.result = result
        for sender in senders {
            sender.continuation.resume(throwing: AsyncHandoffFinishedError())
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

    package func finish(throwing error: any Error) {
        finish(with: .failure(error))
    }

    // Buffers the first waiting sender's element in the space just freed.
    private func admitSender() {
        guard !senders.isEmpty else { return }
        let sender = senders.removeFirst()
        buffer.append(sender.element)
        sender.continuation.resume()
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

/// Thrown by `AsyncHandoff.send(_:)` once the handoff is finished, so that a
/// sender can tell the receiver ending apart from its own cancellation.
package struct AsyncHandoffFinishedError: Error, Equatable {
    package init() { }
}
