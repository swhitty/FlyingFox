//
//  Mutex.swift
//  swift-mutex
//
//  Created by Simon Whitty on 07/09/2024.
//  Copyright 2024 Simon Whitty
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/swhitty/swift-mutex
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

// Backports the Swift 6.0 Mutex API
@usableFromInline
package struct Mutex<Value>: @unchecked Sendable {
    let storage: Storage
}

#if compiler(>=6)
package extension Mutex {

    @usableFromInline
    init(_ initialValue: consuming sending Value) {
        self.storage = Storage(initialValue)
    }

    @usableFromInline
    borrowing func withLock<Result, E: Error>(
        _ body: (inout sending Value) throws(E) -> sending Result
    ) throws(E) -> sending Result {
        storage.lock()
        defer { storage.unlock() }
        return try body(&storage.value)
    }

    @usableFromInline
    borrowing func withLockIfAvailable<Result, E>(
        _ body: (inout sending Value) throws(E) -> sending Result
    ) throws(E) -> sending Result? where E: Error {
        guard storage.tryLock() else { return nil }
        defer { storage.unlock() }
        return try body(&storage.value)
    }
}
#else
package extension Mutex {

    @usableFromInline
    init(_ initialValue: Value) {
        self.storage = Storage(initialValue)
    }

    @usableFromInline
    borrowing func withLock<Result>(
        _ body: (inout Value) throws -> Result
    ) rethrows -> Result {
        storage.lock()
        defer { storage.unlock() }
        return try body(&storage.value)
    }

    @usableFromInline
    borrowing func withLockIfAvailable<Result>(
        _ body: (inout Value) throws -> Result
    ) rethrows -> Result? {
        guard storage.tryLock() else { return nil }
        defer { storage.unlock() }
        return try body(&storage.value)
    }
}
#endif

#if canImport(Darwin)

import struct os.os_unfair_lock_t
import struct os.os_unfair_lock
import func os.os_unfair_lock_lock
import func os.os_unfair_lock_unlock
import func os.os_unfair_lock_trylock

extension Mutex {

    final class Storage {
        private let _lock: os_unfair_lock_t

        var value: Value

        init(_ initialValue: Value) {
            self._lock = .allocate(capacity: 1)
            self._lock.initialize(to: os_unfair_lock())
            self.value = initialValue
        }

        func lock() {
            os_unfair_lock_lock(_lock)
        }

        func unlock() {
            os_unfair_lock_unlock(_lock)
        }

        func tryLock() -> Bool {
            os_unfair_lock_trylock(_lock)
        }

        deinit {
            self._lock.deinitialize(count: 1)
            self._lock.deallocate()
        }
    }
}

#elseif canImport(Glibc)

import Glibc

extension Mutex {

    final class Storage {
        private let _lock: UnsafeMutablePointer<pthread_mutex_t>

        var value: Value

        init(_ initialValue: Value) {
            var attr = pthread_mutexattr_t()
            pthread_mutexattr_init(&attr)
            self._lock = .allocate(capacity: 1)
            let err = pthread_mutex_init(self._lock, &attr)
            precondition(err == 0, "pthread_mutex_init error: \(err)")
            self.value = initialValue
        }

        func lock() {
            let err = pthread_mutex_lock(_lock)
            precondition(err == 0, "pthread_mutex_lock error: \(err)")
        }

        func unlock() {
            let err = pthread_mutex_unlock(_lock)
            precondition(err == 0, "pthread_mutex_unlock error: \(err)")
        }

        func tryLock() -> Bool {
            pthread_mutex_trylock(_lock) == 0
        }

        deinit {
            let err = pthread_mutex_destroy(self._lock)
            precondition(err == 0, "pthread_mutex_destroy error: \(err)")
            self._lock.deallocate()
        }
    }
}

#elseif canImport(WinSDK)

import ucrt
import WinSDK

extension Mutex {

    final class Storage {
        private let _lock: UnsafeMutablePointer<SRWLOCK>

        var value: Value

        init(_ initialValue: Value) {
            self._lock = .allocate(capacity: 1)
            InitializeSRWLock(self._lock)
            self.value = initialValue
        }

        func lock() {
            AcquireSRWLockExclusive(_lock)
        }

        func unlock() {
            ReleaseSRWLockExclusive(_lock)
        }

        func tryLock() -> Bool {
            TryAcquireSRWLockExclusive(_lock)
        }
    }
}

#endif

package extension Mutex where Value: Sendable {
    func copy() -> Value {
        withLock { $0 }
    }
}
