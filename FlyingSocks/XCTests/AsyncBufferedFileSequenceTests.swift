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
import XCTest

final class AsyncBufferedFileSequenceTests: XCTestCase {

    func testFileSize() {
        XCTAssertEqual(
            try AsyncBufferedFileSequence.fileSize(at: .jackOfHeartsRecital),
            299
        )
        XCTAssertThrowsError(
            try AsyncBufferedFileSequence.fileSize(at: URL(fileURLWithPath: "missing"))
        )

        XCTAssertThrowsError(
            try AsyncBufferedFileSequence.fileSize(from: [:])
        )
    }

    func testFileHandleRead() throws {
        let handle = try FileHandle(forReadingFrom: .jackOfHeartsRecital)
        XCTAssertEqual(
            try handle.read(suggestedCount: 14, forceLegacy: false),
            "Two doors down".data(using: .utf8)
        )
        XCTAssertEqual(
            try handle.read(suggestedCount: 9, forceLegacy: true),
            " the boys".data(using: .utf8)
        )
    }

    func testReadsEntireFile() async {
        let sequence = AsyncBufferedFileSequence(contentsOf: .jackOfHeartsRecital)

        await AsyncAssertEqual(
            try await sequence.getAllData(),
            try Data(contentsOf: .jackOfHeartsRecital)
        )
    }
}

private extension URL {
    static var jackOfHeartsRecital: URL {
        Bundle.module.url(forResource: "Resources", withExtension: nil)!
            .appendingPathComponent("JackOfHeartsRecital.txt")
    }
}
