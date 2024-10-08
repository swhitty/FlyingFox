//
//  HTTPBodyPatternTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 13/02/2022.
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
import Foundation
import Testing

struct HTTPBodyPatternTests {

#if canImport(Darwin)
    @Test
    func bodyArray_MatchesRoute() {
        let pattern = JSONPredicatePattern.json(where: "animals[1].name == 'fish'")

        #expect(
            pattern.evaluate(
              #"""
              {
                "animals": [
                  {"name": "dog"},
                  {"name": "fish"}
                ]
              }
              """#.data(using: .utf8)!
            )
        )

        #expect(
            !pattern.evaluate(
              #"""
              {
                "animals": [
                  {"name": "fish"},
                  {"name": "dog"}
                ]
              }
              """#.data(using: .utf8)!
            )
        )

        #expect(
            !pattern.evaluate(
                Data([0x01, 0x02])
            )
        )
    }
#endif
}
