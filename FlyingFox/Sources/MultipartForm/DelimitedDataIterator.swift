//
//  DelimitedDataIterator.swift
//  FlyingFox
//
//  Created by Simon Whitty on 12/11/2023.
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

import Foundation

struct DelimitedDataIterator<I: AsyncIteratorProtocol> where I.Element == Data {

    private var iterator: I
    private let delimiter: Data

    init(iterator: I, delimiter: Data) {
        self.iterator = iterator
        self.delimiter = delimiter
    }

    private var buffer = Data()
    private var isComplete: Bool = false

    private mutating func bufferedRange(of delimiter: Data) async throws -> Range<Int>? {
        if let range = buffer.firstRange(of: delimiter) {
            return range
        }
        guard !isComplete else { return nil }
        while let data = try await iterator.next() {
            buffer.append(data)
            if let range = buffer.firstRange(of: delimiter) {
                return range
            }
        }
        isComplete = true
        return nil
    }

    mutating func next(of match: Data) async throws -> Data? {
        if let range = try await bufferedRange(of: match) {
            buffer = Data(buffer[range.endIndex...])
            return match
        }
        return nil
    }

    mutating func nextUntil(_ match: Data) async throws -> Data? {
        guard let range = try await bufferedRange(of: match) else {
            defer { buffer = Data() }
            return buffer.isEmpty ? nil : buffer
        }

        let slice = Data(buffer[..<range.startIndex])
        buffer = Data(buffer[range.endIndex...])

        return slice
    }

    mutating func next() async throws -> Data? {
        try await nextUntil(delimiter)
    }

    private func firstBufferedRange(of delimiters: Data...) -> (delimited: Data, range: Range<Int>)? {
        for delimiter in delimiters {
            if let range = buffer.firstRange(of: delimiter) {
                return (delimiter, range)
            }
        }
        return nil
    }

    private mutating func AbufferedRange(of delimiter: Data) async throws -> Range<Int>? {
        if let range = buffer.firstRange(of: delimiter) {
            return range
        }
        guard !isComplete else { return nil }
        while let data = try await iterator.next() {
            buffer.append(data)
            if let range = buffer.firstRange(of: delimiter) {
                return range
            }
        }
        isComplete = true
        return nil
    }

    enum Part {
        case data(Data)
        case delimiter(Data)
        case end
    }


}

extension Data {

    enum Match: Equatable {
        case partial(Range<Index>)
        case complete(Range<Index>)
    }

    func firstMatch(of data: Data) -> Match? {
        firstMatch(of: data, from: startIndex)
    }

    func firstMatch(of data: Data, from idx: Index) -> Match? {
        guard !data.isEmpty else { return nil }

        var position = idx

        while position < endIndex {
            switch matches(data, at: position) {
            case .complete(let range):
                return .complete(range)
            case .partial(let range):
                position = range.upperBound
                if position == endIndex {
                    return .partial(range)
                }
            case .none:
                position = index(after: position)
            }
        }
        return nil
    }

    func matches(_ data: Data, at idx: Index) -> Match? {
        var haystackIndex = idx
        var needleIndex = data.startIndex

        while true {
            guard self[haystackIndex] == data[needleIndex] else {
                if needleIndex == data.startIndex {
                    // at start no match
                    return nil
                } else {
                    // partial match
                    return .partial(idx..<haystackIndex)
                }
            }

            haystackIndex = index(after: haystackIndex)
            needleIndex = data.index(after: needleIndex)

            if needleIndex == data.endIndex {
                return .complete(idx..<haystackIndex)
            } else if haystackIndex == endIndex {
                return .partial(idx..<haystackIndex)
            }
        }
    }
}
