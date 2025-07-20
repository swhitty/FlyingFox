//
//  DelimitedDataIteratorTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 13/11/2023.
//  Copyright © 2023 Simon Whitty. All rights reserved.
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
import Foundation
import Testing

struct DelimitedDataIteratorTests {

    @Test
    func sequence() async throws {
        var data = DelimitedDataIterator.make(body:
            #"""
            abc-xyz
            123-456-789
            """#,
            delimiter: "-"
        )

        #expect(
            try await data.collectAllStrings() == [
                "abc",
                "xyz\n123",
                "456",
                "789"
            ]
        )
    }

    @Test
    func data() {
        let data = "Fish chips fishes fisherman-".utf8

        #expect(
            data.firstMatch(of: "chips".utf8) == .complete(5..<10)
        )
        #expect(
            data.firstMatch(of: "sh".utf8) == .complete(2..<4)
        )
        #expect(
            data.firstMatch(of: "fisher".utf8) == .complete(18..<24)
        )
        #expect(
            data.firstMatch(of: "man-".utf8) == .complete(24..<28)
        )
        #expect(
            data.firstMatch(of: "man-df".utf8) == .partial(24..<28)
        )
    }

    @Test
    func testDataA() {
        let data = "Fish".utf8

        #expect(
            data.matches("sher".data(using: .utf8)!, at: 2) == .partial(2..<4)
        )
        #expect(
            data.firstMatch(of: "sher".utf8) == .partial(2..<4)
        )
    }
}

private extension DelimitedDataIterator where I == HTTPBodySequence.AsyncIterator {

    static func make(body: String, chunkSize: Int = 5, delimiter: String = "\n") -> Self {
        let sequence = HTTPBodySequence(
            data: body.data(using: .utf8)!,
            suggestedBufferSize: 5
        )

        return DelimitedDataIterator(
            iterator: sequence.makeAsyncIterator(),
            delimiter: delimiter.data(using: .utf8)!
        )
    }

    mutating func readString() async throws -> String? {
        guard let data = try await next() else {
            return nil
        }
        return String(data: data, encoding: .utf8)!
    }

    mutating func collectAllStrings() async throws -> [String] {
        var strings = [String]()

        while let data = try await next() {
            strings.append(String(data: data, encoding: .utf8)!)
        }

        return strings
    }

}

private extension String {
    var utf8: Data {
        data(using: .utf8)!
    }
}
