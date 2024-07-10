//
//  AsyncBufferedDataSequence.swift
//  FlyingFox
//
//  Created by Simon Whitty on 10/07/2024.
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

import Foundation

@_spi(Private)
public struct AsyncBufferedCollection<C: Collection>: AsyncBufferedSequence {
    public typealias Element = C.Element

    private let collection: C

    public init(_ collection: C) {
        self.collection = collection
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(collection: collection)
    }

    public struct Iterator: AsyncBufferedIteratorProtocol {

        private let collection: C
        private var index: C.Index

        init(collection: C) {
            self.collection = collection
            self.index = collection.startIndex
        }

        public mutating func next() async throws -> C.Element? {
            guard index < collection.endIndex else { return nil }
            let element = collection[index]
            index = collection.index(after: index)
            return element
        }

        public mutating func nextBuffer(atMost count: Int) async -> C.SubSequence? {
            guard index < collection.endIndex else { return nil }
            let endIndex = collection.index(index, offsetBy: count, limitedBy: collection.endIndex) ?? collection.endIndex
            let buffer = collection[index..<endIndex]
            index = endIndex
            return buffer
        }
    }
}

extension AsyncBufferedCollection: Sendable where C: Sendable { }


public extension AsyncBufferedCollection<Data> {
    init(bytes: some Sequence<UInt8>) {
        self.init(Data(bytes))
    }
}

