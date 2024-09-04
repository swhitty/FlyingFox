//
//  AsyncBufferedEmptySequenceTests.swift
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

struct AsyncBufferedEmptySequenceTests {

    @Test
    func completesImmediatley() async {
        var iterator = AsyncBufferedEmptySequence<Int>(completeImmediately: true)
            .makeAsyncIterator()

        #expect(
            await iterator.nextBuffer(suggested: 1) == nil
        )
    }

    @Test
    func cancels_AfterWaiting() async {
        let task = Task {
            await AsyncBufferedEmptySequence<Int>(completeImmediately: false)
                .first { _ in true }
        }

        try? await Task.sleep(seconds: 0.05)
        task.cancel()
        #expect(
            await task.value == nil
        )
    }

    @Test
    func cancels_Immediatley() async {
        let task = Task {
            try? await Task.sleep(seconds: 0.05)
            var iterator = AsyncBufferedEmptySequence<Int>(completeImmediately: false)
                .makeAsyncIterator()
            return await iterator.nextBuffer(suggested: 1)
        }

        task.cancel()
        #expect(
            await task.value == nil
        )
    }
}
