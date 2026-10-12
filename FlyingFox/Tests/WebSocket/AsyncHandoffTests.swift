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

@testable import FlyingFox
@testable import FlyingSocks
import Foundation
import Testing

struct AsyncHandoffTests {

    @Test
    func send_Suspends_UntilElementIsTaken() async throws {
        let handoff = AsyncHandoff<Int>()
        let sent = Mutex([Int]())
        let sender = Task {
            for element in 1...3 {
                try await handoff.send(element)
                sent.withLock { $0.append(element) }
            }
        }

        #expect(try await handoff.next() == 1)
        // The second send cannot complete until the receiver takes it.
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
    func finish_CancelsWaitingSenders() async throws {
        let handoff = AsyncHandoff<String>()
        let sender = Task { try await handoff.send("Fish") }
        await handoff.finish()

        await #expect(throws: CancellationError.self) {
            try await sender.value
        }
        #expect(try await handoff.next() == nil)
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
}
