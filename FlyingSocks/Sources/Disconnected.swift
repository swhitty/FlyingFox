//
//  Disconnected.swift
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

/// A wrapper that keeps a value in a disconnected isolation region, so it can be
/// stored (for example in an actor) and later sent across an isolation boundary
/// even when the value is not `Sendable`.
///
/// Values enter and leave only through `sending` boundaries, so the compiler checks
/// each one is disconnected. This mirrors the `Disconnected` type from SE-0538, which
/// arrives in the Synchronization module with Swift 6.5. Replace this with the
/// standard library type once the minimum supported Swift version includes it.
package struct Disconnected<Value: ~Copyable>: ~Copyable, Sendable {
    // Safety: every value stored here enters through a `sending` boundary, there is no
    // borrowing access, and every operation either consumes the wrapper or restores a
    // value received through `sending`.
    private nonisolated(unsafe) var value: Value

    /// Creates a wrapper that takes ownership of a disconnected value.
    package init(_ value: consuming sending Value) {
        self.value = value
    }

    /// Consumes the wrapper and returns its value in a disconnected region.
    package consuming func consume() -> sending Value {
        value
    }

    /// Replaces the stored value and returns the previous value, disconnected.
    @discardableResult
    package mutating func exchange(newValue: consuming sending Value) -> sending Value {
        let oldValue = (consume self).consume()
        self = Disconnected(newValue)
        return oldValue
    }

    // Swift 6.2 and earlier reject restoring `value` after `body` throws.
    #if compiler(>=6.3)
    /// Calls `body` with mutable `sending` access to the stored value.
    ///
    /// The closure must leave a disconnected value in the supplied storage.
    package mutating func withValue<Result: ~Copyable, Failure>(
        body: (inout sending Value) throws(Failure) -> Result
    ) throws(Failure) -> Result {
        var value = (consume self).consume()
        let result: Result
        do throws(Failure) {
            result = try body(&value)
        } catch {
            self = Disconnected(value)
            throw error
        }
        self = Disconnected(value)
        return result
    }
    #endif
}
