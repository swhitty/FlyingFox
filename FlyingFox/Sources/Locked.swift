//
//  Locked.swift
//  FlyingFox
//
//  Created by Simon Whitty on 24/03/2022.
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

import Foundation

@propertyWrapper
final class Locked<Value> {
  private var value: Value

  init(wrappedValue initialValue: Value) {
    self.value = initialValue
  }

  @available(*, unavailable, message: "@Locked can only be applied to classes")
  var wrappedValue: Value { get { fatalError() } set { fatalError() } }

    // Classes get and set `wrappedValue` using this subscript.
  static subscript<T>(_enclosingInstance instance: T,
                      wrapped wrappedKeyPath: ReferenceWritableKeyPath<T, Value>,
                      storage storageKeyPath: ReferenceWritableKeyPath<T, Locked>) -> Value {
    get {
        instance[keyPath: storageKeyPath].unlock { $0 }
    }
    set {
        instance[keyPath: storageKeyPath].unlock {
            $0 = newValue
        }
    }
  }

  @discardableResult
  func unlock<U>(_ transform: (inout Value) throws -> U) rethrows -> U {
    lock.lock()
    defer { lock.unlock() }
    return try transform(&value)
  }

  private let lock = NSLock()
}

extension Locked: @unchecked Sendable where Value: Sendable { }
