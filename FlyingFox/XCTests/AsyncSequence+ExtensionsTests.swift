//
//  AsyncSequence+ExtensionsTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 13/03/2022.
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

@testable import FlyingFox
import FlyingSocks
import XCTest

final class AsyncSequenceExtensionTests: XCTestCase {

    func testCollectStrings() async throws {
        var iterator = ConsumingAsyncSequence("fish,chips".data(using: .utf8)!)
            .collectStrings(separatedBy: ",")
            .makeAsyncIterator()
//
        await AsyncAssertEqual(try await iterator.next(), "fish")
        await AsyncAssertEqual(try await iterator.next(), "chips")
        await AsyncAssertEqual(try await iterator.next(), nil)
    }

    func testCollectStringsWithTrailingSeperator() async throws {
        var iterator = ConsumingAsyncSequence("fish,chips,".data(using: .utf8)!)
            .collectStrings(separatedBy: ",")
            .makeAsyncIterator()

        await AsyncAssertEqual(try await iterator.next(), "fish")
        await AsyncAssertEqual(try await iterator.next(), "chips")
        await AsyncAssertEqual(try await iterator.next(), nil)
    }

    func testCollectStringsWithTrailingSeperatorA() async throws {
        var iterator = ConsumingAsyncSequence([0x61, 0x2c, 0x62, 0x2c, 0xff])
            .collectStrings(separatedBy: ",")
            .makeAsyncIterator()

        await AsyncAssertEqual(try await iterator.next(), "a")
        await AsyncAssertEqual(try await iterator.next(), "b")
        await AsyncAssertThrowsError(try await iterator.next(), of: AsyncSequenceError.self)
    }

    func testTakeNextThrowsError_WhenSequenceEnds() async {
        let sequence = ConsumingAsyncSequence(bytes: [])

        await AsyncAssertThrowsError(try await sequence.takeNext(), of: SequenceTerminationError.self)
    }
}


