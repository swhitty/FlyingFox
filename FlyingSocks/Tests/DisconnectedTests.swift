//
//  DisconnectedTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 14/11/2026.
//  Copyright © 2026 Simon Whitty. All rights reserved.
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
import Testing

struct DisconnectedTests {

    @Test
    func consume_ReturnsValue() {
        let wrapper = Disconnected(Fish("fish"))
        #expect(wrapper.consume().value == "fish")
    }

    @Test
    func exchange_ReturnsPreviousValue() {
        var wrapper = Disconnected(Fish("fish"))
        #expect(wrapper.exchange(newValue: Fish("chips")).value == "fish")
        #expect(wrapper.consume().value == "chips")
    }

    #if compiler(>=6.3)
    @Test
    func withValue_MutatesValue() {
        var wrapper = Disconnected(Fish("fish"))
        let count = wrapper.withValue {
            $0.value += " & chips"
            return $0.value.count
        }
        #expect(count == 12)
        #expect(wrapper.consume().value == "fish & chips")
    }

    @Test
    func withValue_KeepsValue_WhenBodyThrows() {
        var wrapper = Disconnected(Fish("fish"))
        #expect(throws: CancellationError.self) {
            try wrapper.withValue {
                $0.value = "chips"
                throw CancellationError()
            }
        }
        #expect(wrapper.consume().value == "chips")
    }
    #endif
}

private final class Fish {
    var value: String

    init(_ value: String) {
        self.value = value
    }
}
