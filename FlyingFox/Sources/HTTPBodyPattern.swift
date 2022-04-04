//
//  HTTPBodyPattern.swift
//  FlyingFox
//
//  Created by Simon Whitty on 5/03/2022.
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

public protocol HTTPBodyPattern: Sendable {
    func evaluate(_ body: Data) -> Bool
}

#if canImport(Darwin)
public struct JSONPredicatePattern: HTTPBodyPattern {

    @UncheckedSendable private var predicate: NSPredicate

    public init(_ predicate: NSPredicate) {
        self.predicate = predicate
    }

    public func evaluate(_ body: Data) -> Bool {
        do {
            let object = try JSONSerialization.jsonObject(with: body, options: [])
            return predicate.evaluate(with: object)
        } catch {
            return false
        }
    }
}

public extension HTTPBodyPattern where Self == JSONPredicatePattern {

    static func json(where condition: String) -> JSONPredicatePattern {
        JSONPredicatePattern(NSPredicate(format: condition))
    }
}

#endif
