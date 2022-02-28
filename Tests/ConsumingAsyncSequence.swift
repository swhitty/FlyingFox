//
//  ConsumingAsyncSequence.swift
//  FlyingFox
//
//  Created by Simon Whitty on 17/02/2022.
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

final class ConsumingAsyncSequence<Element>: ChunckedAsyncSequence, ChunckedAsyncIteratorProtocol {

    private var iterator: AnySequence<Element>.Iterator

    init<T: Sequence>(_ sequence: T) where T.Element == Element {
        self.iterator = AnySequence(sequence).makeIterator()
    }

    func makeAsyncIterator() -> ConsumingAsyncSequence<Element> { self }

    func next() async throws -> Element? {
        iterator.next()
    }

    func nextChunk(count: Int) async throws -> [Element]? {
        var buffer = [Element]()
        while buffer.count < count,
              let element = iterator.next() {
            buffer.append(element)
        }

        return buffer.count == count ? buffer : nil
    }
}
