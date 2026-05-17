//
//  AsyncBufferingSequence.swift
//  FlyingFox
//
//  Wraps an AsyncBufferedSequence with a shared in-memory buffer so that
//  multiple iterators created from the same wrapper consume from the same
//  underlying stream without losing bytes pulled-but-not-yet-consumed when
//  one iterator is dropped.
//
//  Distributed under the permissive MIT license.
//

private extension Transferring where Value: AsyncBufferedIteratorProtocol {
    mutating func nextBuffer(suggested count: Int) async throws -> Transferring<Value.Buffer>? {
        guard let buffer = try await value.nextBuffer(suggested: count) else { return nil }
        return Transferring<Value.Buffer>(buffer)
    }
}

/// AsyncBufferedSequence that adds a shared in-memory buffer over a base
/// sequence. Bytes pulled from the base by one iterator remain available to
/// subsequent iterators on the same wrapper — required when a consumer
/// (e.g. the HTTP decoder) constructs multiple iterators against the same
/// stream and must not lose bytes between them.
///
/// This is consuming, not replaying: each byte is returned to exactly one
/// `next()` / `nextBuffer(suggested:)` call across all iterators.
package struct AsyncBufferingSequence<Base>: AsyncBufferedSequence, Sendable
where Base: AsyncBufferedSequence, Base.Element: Sendable {

    package typealias Element = Base.Element

    private let storage: Storage

    package init(_ base: Base, suggestedBufferSize: Int = 4096) {
        self.storage = Storage(base: base, suggestedBufferSize: suggestedBufferSize)
    }

    package func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(storage: storage)
    }

    package struct AsyncIterator: AsyncBufferedIteratorProtocol {
        package typealias Buffer = ArraySlice<Element>

        private let storage: Storage

        init(storage: Storage) {
            self.storage = storage
        }

        package mutating func next() async throws -> Element? {
            try await storage.popOne()
        }

        package mutating func nextBuffer(suggested count: Int) async throws -> ArraySlice<Element>? {
            try await storage.popBuffer(suggested: count)
        }
    }
}

extension AsyncBufferingSequence {

    /// Storage actor backing one or more iterators against a base sequence.
    ///
    /// Designed for *serial* consumption from a single task graph (e.g. one
    /// connection at a time): the actor's isolation guarantees a single in-flight
    /// `refill` per wrapper, and the iterators created from `makeAsyncIterator()`
    /// share the same backing buffer so bytes pulled from the base are never lost
    /// between iterators.
    final actor Storage {

        private var iterator: Base.AsyncIterator?    // nil after EOF (or transiently during refill)
        private var buffer: [Element] = []
        private var consumed: Int = 0
        private let suggestedBufferSize: Int

        init(base: Base, suggestedBufferSize: Int) {
            self.iterator = base.makeAsyncIterator()
            self.suggestedBufferSize = suggestedBufferSize
        }

        private var available: Int { buffer.count - consumed }

        func popOne() async throws -> Element? {
            if available == 0, try await refill(suggested: suggestedBufferSize) == false {
                return nil
            }
            let element = buffer[consumed]
            consumed += 1
            return element
        }

        func popBuffer(suggested count: Int) async throws -> ArraySlice<Element>? {
            guard count > 0 else { return [] }
            if available == 0,
               try await refill(suggested: Swift.max(count, suggestedBufferSize)) == false {
                return nil
            }
            let take = Swift.min(count, available)
            let slice = buffer[consumed..<(consumed + take)]
            consumed += take
            return slice
        }

        // Returns true when bytes were pulled into the buffer, false at EOF.
        // Wraps the iterator in `Transferring` to call a mutating async on a
        // value-type iterator without tripping actor-isolation/sendability.
        // Same idiom as AsyncSharedReplaySequence.requestNextChunk.
        private func refill(suggested count: Int) async throws -> Bool {
            guard let iter = iterator else { return false }
            iterator = nil
            var transferring = Transferring(iter)
            let chunk: Base.AsyncIterator.Buffer?
            do {
                chunk = try await transferring.nextBuffer(suggested: count)?.value
            } catch {
                iterator = transferring.value
                throw error
            }
            iterator = transferring.value
            guard let chunk, !chunk.isEmpty else {
                iterator = nil   // EOF
                return false
            }
            buffer = Array(chunk)
            consumed = 0
            return true
        }
    }
}
