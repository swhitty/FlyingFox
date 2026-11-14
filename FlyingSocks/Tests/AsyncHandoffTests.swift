//
//  AsyncHandoffTests.swift
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
import Foundation
import Testing

struct AsyncHandoffTests {

    @Test
    func send_Suspends_UntilElementIsReceived() async throws {
        let handoff = AsyncHandoff<Int>()
        let sent = Mutex([Int]())
        let sender = Task {
            for element in 1...3 {
                try await handoff.send(element)
                sent.withLock { $0.append(element) }
            }
        }

        #expect(try await handoff.next() == 1)
        // The second send cannot complete until the receiver has it.
        #expect(sent.withLock { !$0.contains(2) })
        #expect(try await handoff.next() == 2)
        #expect(try await handoff.next() == 3)
        try await sender.value
        #expect(sent.withLock { $0 } == [1, 2, 3])
    }

    @Test
    func next_Suspends_UntilElementIsSent() async throws {
        let handoff = AsyncHandoff<String>()
        let receiver = Task { try await handoff.next() }

        try await handoff.send("Fish")
        #expect(try await receiver.value == "Fish")
    }

    @Test
    func finish_EndsReceiver() async throws {
        let handoff = AsyncHandoff<String>()
        await handoff.finish()

        #expect(try await handoff.next() == nil)
    }

    @Test
    func finish_DeliversFinalElement_ThenEnds() async throws {
        let handoff = AsyncHandoff<String>()
        await handoff.finish(with: .success("Chips"))

        #expect(try await handoff.next() == "Chips")
        #expect(try await handoff.next() == nil)
    }

    @Test
    func finish_DeliversError_ThenEnds() async throws {
        let handoff = AsyncHandoff<String>()
        let receiver = Task { try await handoff.next() }
        await handoff.finish(throwing: SocketError.disconnected)

        await #expect(throws: SocketError.disconnected) {
            try await receiver.value
        }
        #expect(try await handoff.next() == nil)
    }

    @Test
    func finish_EndsWaitingSenders() async throws {
        let handoff = AsyncHandoff<String>()
        let sender = Task { try await handoff.send("Fish") }
        await handoff.finish()

        await #expect(throws: AsyncHandoffFinishedError.self) {
            try await sender.value
        }
        #expect(try await handoff.next() == nil)
    }

    @Test
    func send_ThrowsFinishedError_WhenFinished() async throws {
        let handoff = AsyncHandoff<String>()
        await handoff.finish()

        await #expect(throws: AsyncHandoffFinishedError.self) {
            try await handoff.send("Fish")
        }
    }

    @Test
    func send_ThrowsCancellationError_WhenSenderIsCancelled() async throws {
        let handoff = AsyncHandoff<String>()
        let sender = Task { try await handoff.send("Fish") }
        sender.cancel()

        await #expect(throws: CancellationError.self) {
            try await sender.value
        }
        // The cancelled element is not delivered.
        await handoff.finish()
        #expect(try await handoff.next() == nil)
    }

    @Test
    func next_ReturnsNil_WhenReceiverIsCancelled() async throws {
        let handoff = AsyncHandoff<String>()
        let receiver = Task { try await handoff.next() }
        receiver.cancel()

        #expect(try await receiver.value == nil)
    }

    @Test
    func send_DoesNotSuspend_WhileBufferHasSpace() async throws {
        let handoff = AsyncHandoff<Int>(capacity: 2)
        try await handoff.send(1)
        try await handoff.send(2)

        let sent = Mutex(false)
        let sender = Task {
            try await handoff.send(3)
            sent.withLock { $0 = true }
        }

        #expect(try await handoff.next() == 1)
        try await sender.value
        #expect(sent.withLock { $0 })
        #expect(try await handoff.next() == 2)
        #expect(try await handoff.next() == 3)
    }

    @Test
    func send_Suspends_WhileBufferIsFull() async throws {
        let handoff = AsyncHandoff<Int>(capacity: 1)
        let sent = Mutex([Int]())
        let sender = Task {
            for element in 1...3 {
                try await handoff.send(element)
                sent.withLock { $0.append(element) }
            }
        }

        #expect(try await handoff.next() == 1)
        // 2 may be buffered, but 3 waits until 2 is received.
        #expect(sent.withLock { !$0.contains(3) })
        #expect(try await handoff.next() == 2)
        #expect(try await handoff.next() == 3)
        try await sender.value
        #expect(sent.withLock { $0 } == [1, 2, 3])
    }

    @Test
    func finish_DeliversBufferedElements_BeforeFinalElement() async throws {
        let handoff = AsyncHandoff<String>(capacity: 2)
        try await handoff.send("Fish")
        try await handoff.send("Chips")
        await handoff.finish(with: .success("Peas"))

        #expect(try await handoff.next() == "Fish")
        #expect(try await handoff.next() == "Chips")
        #expect(try await handoff.next() == "Peas")
        #expect(try await handoff.next() == nil)
    }

    @Test
    func send_ThrowsCancellationError_WhenSenderIsCancelled_WhileBufferIsFull() async throws {
        let handoff = AsyncHandoff<String>(capacity: 1)
        try await handoff.send("Fish")
        let sender = Task { try await handoff.send("Chips") }
        sender.cancel()

        await #expect(throws: CancellationError.self) {
            try await sender.value
        }
        await handoff.finish()
        #expect(try await handoff.next() == "Fish")
        #expect(try await handoff.next() == nil)
    }
}
