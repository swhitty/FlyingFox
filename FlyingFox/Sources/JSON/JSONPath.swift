//
//  JSONPath.swift
//  FlyingFox
//
//  Created by Simon Whitty on 29/05/2023.
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

public struct JSONPath {

    var components: [Component]

    enum Component: Equatable {
        case field(String)
        case array(Int)
    }

    init(components: [Component]) {
        self.components = components
    }

    public init(parsing path: String) throws {
        self.components = try Self.parseComponents(from: path)
    }

    private struct Error: LocalizedError {
        var errorDescription: String?

        init(_ description: String) {
            self.errorDescription = description
        }
    }
}

extension JSONPath {

    static func parseComponents(from path: String) throws -> [Component] {
        var scanner = Scanner(string: path)
        guard scanner.scanString("$") != nil else {
            throw Error("Expected $")
        }

        var comps = [Component]()
        while let comp = try scanComponent(from: &scanner) {
            comps.append(comp)
        }
        return comps
    }

    static func scanComponent(from scanner: inout Scanner) throws -> Component? {
        if scanner.scanString(".") != nil {
            guard let name = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ".[")) else {
                throw Error("Expected field name")
            }
            return .field(name)
        } else if scanner.scanString("[") != nil {
            guard let index = scanner.scanCharacters(from: CharacterSet(charactersIn: "0123456789")) else {
                throw Error("Expected index")
            }
            guard scanner.scanString("]") != nil else {
                throw Error("Expected ]")
            }
            return .array(Int(index)!)
        }
        guard scanner.isAtEnd else {
            throw Error("Expected end")
        }
        return nil
    }
}
