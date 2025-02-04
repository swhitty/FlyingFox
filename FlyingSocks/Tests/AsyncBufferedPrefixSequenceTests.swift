//
//  AsyncBufferedPrefixSequenceTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 04/02/2025.
//  Copyright © 2025 Simon Whitty. All rights reserved.
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

@testable import FlyingSocks
import Foundation
import Testing

struct AsyncBufferedPrefixSequenceTests {

    @Test
    func next_terminates_after_count() async throws {
        let buffer = AsyncBufferedCollection(["a", "b", "c", "d", "e", "f"])
        var prefix = AsyncBufferedPrefixSequence(base: buffer, count: 4).makeAsyncIterator()

        #expect(
            try await prefix.next() == "a"
        )
        #expect(
            try await prefix.next() == "b"
        )
        #expect(
            try await prefix.next() == "c"
        )
        #expect(
            try await prefix.next() == "d"
        )
        #expect(
            try await prefix.next() == nil
        )
    }

    @Test
    func nextBuffer_terminates_after_count() async throws {
        let buffer = AsyncBufferedCollection(["a", "b", "c", "d", "e", "f"])
        var prefix = AsyncBufferedPrefixSequence(base: buffer, count: 4).makeAsyncIterator()

        #expect(
            try await prefix.nextBuffer(suggested: 3) == ["a", "b", "c"]
        )
        #expect(
            try await prefix.nextBuffer(suggested: 3) == ["d"]
        )
        #expect(
            try await prefix.nextBuffer(suggested: 3) == nil
        )
    }

    @Test
    func next_terminates_when_base_terminates() async throws {
        let buffer = AsyncBufferedCollection(["a"])
        var prefix = AsyncBufferedPrefixSequence(base: buffer, count: 2).makeAsyncIterator()

        #expect(
            try await prefix.next() == "a"
        )
        #expect(
            try await prefix.next() == nil
        )
    }

    @Test
    func nextBuffer_terminates_when_base_terminates() async throws {
        let buffer = AsyncBufferedCollection(["a"])
        var prefix = AsyncBufferedPrefixSequence(base: buffer, count: 10).makeAsyncIterator()

        #expect(
            try await prefix.nextBuffer(suggested: 3) == ["a"]
        )
        #expect(
            try await prefix.nextBuffer(suggested: 3) == nil
        )
    }
}
