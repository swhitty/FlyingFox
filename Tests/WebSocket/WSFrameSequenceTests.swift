//
//  WSFrameSequenceTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 18/03/2022.
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
import Foundation
import XCTest

final class WSFrameSequenceTests: XCTestCase {

    func testSequenceDecodesFramesFromBytes() async throws {
        await XCTAssertEqualAsync(
            try await WSFrameSequence.make([.fish, .chips, .close]).collectAll(),
            [.fish, .chips, .close]
        )
        await XCTAssertEqualAsync(
            try await WSFrameSequence.make([.close]).collectAll(),
            [.close]
        )
        await XCTAssertEqualAsync(
            try await WSFrameSequence.make([]).collectAll(),
            []
        )
    }
}

private extension WSFrame {
    static let fish = WSFrame.make(payload: "Fish".data(using: .utf8)!)
    static let chips = WSFrame.make(payload: "Chips".data(using: .utf8)!)
    static let close = WSFrame.close(message: "Bye")
}

private extension WSFrameSequence {
    static func make(_ frames: [WSFrame]) -> WSFrameSequence {
        let bytes = ConsumingAsyncSequence(frames.flatMap(WSFrameEncoder.encodeFrame))
        return WSFrameSequence(bytes)
    }
}

private extension AsyncSequence {
    func collectAll() async throws -> [Element] {
        let collect = collectUntil { _ in false }
        var iterator = collect.makeAsyncIterator()
        return try await iterator.next() ?? []
    }
}
