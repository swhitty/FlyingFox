//
//  AsyncBufferedFileSequenceTests.swift
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

@testable import FlyingSocks
import Foundation
import Testing

struct AsyncBufferedFileSequenceTests {

    @Test
    func fileSize() async throws {
        #if os(Windows)
        try #expect(
            AsyncBufferedFileSequence(contentsOf: .jackOfHeartsRecital).fileSize == 304
        )
        #else
        try #expect(
            AsyncBufferedFileSequence(contentsOf: .jackOfHeartsRecital).fileSize == 299
        )
        #endif
        
        #expect(throws: (any Error).self) {
            try AsyncBufferedFileSequence.fileSize(at: URL(fileURLWithPath: "missing"))
        }
        #expect(throws: (any Error).self) {
            try AsyncBufferedFileSequence.fileSize(from: [:])
        }
        #expect(throws: (any Error).self) {
            try AsyncBufferedFileSequence(contentsOf: .jackOfHeartsRecital, range: 0..<1000)
        }
    }

    @Test
    func count() async throws {
        #if os(Windows)
        try #expect(
            AsyncBufferedFileSequence(contentsOf: .jackOfHeartsRecital).count == 304
        )
        #else
        try #expect(
            AsyncBufferedFileSequence(contentsOf: .jackOfHeartsRecital).count == 299
        )
        #endif
        try #expect(
            AsyncBufferedFileSequence(contentsOf: .jackOfHeartsRecital, range: 0..<10).count == 10
        )
        try #expect(
            AsyncBufferedFileSequence(contentsOf: .jackOfHeartsRecital, range: 20..<25).count == 5
        )
    }

    @Test
    func fileHandleRead() throws {
        let handle = try FileHandle(forReadingFrom: .jackOfHeartsRecital)
        #expect(
            try handle.read(suggestedCount: 14, forceLegacy: false) == "Two doors down".data(using: .utf8)
        )
        #expect(
            try handle.read(suggestedCount: 9, forceLegacy: true) == " the boys".data(using: .utf8)
        )
    }

    @Test
    func readsEntireFile() async throws {
        let sequence = try AsyncBufferedFileSequence(contentsOf: .jackOfHeartsRecital)

        #expect(
            try await sequence.getAllData() == Data(contentsOf: .jackOfHeartsRecital)
        )
    }

    @Test
    func readsPartialFile() async throws {
        let sequence = try AsyncBufferedFileSequence(contentsOf: .jackOfHeartsRecital, range: 4..<9)
        #expect(
            try await sequence.readAllToString() == "doors"
        )

        let another = try AsyncBufferedFileSequence(contentsOf: .jackOfHeartsRecital, range: 15..<31)
        #expect(
            try await another.readAllToString() == "the boys finally"
        )
    }
}

private extension URL {
    static var jackOfHeartsRecital: URL {
        Bundle.module.url(forResource: "Resources", withExtension: nil)!
            .appendingPathComponent("JackOfHeartsRecital.txt")
    }
}

private extension AsyncBufferedSequence where Element == UInt8 {

    func readAllToString(suggestedBuffer count: Int = 4096) async throws -> String {
        let data = try await getAllData()
        guard let string = String(data: data, encoding: .utf8) else {
            throw SocketError.disconnected
        }
        return string
    }
}

