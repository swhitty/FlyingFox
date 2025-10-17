//
//  JSONValue.swift
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

public indirect enum JSONValue: Sendable, Hashable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null

    public subscript(jsonPath: String) -> JSONValue? {
        get { try? getValue(for: jsonPath) }
    }

    public func getValue(for jsonPath: String) throws -> JSONValue {
        try getValue(for: JSONPath(parsing: jsonPath))
    }

    public func getValue(for path: JSONPath) throws -> JSONValue {
        var value = self
        for comp in path.components {
            value = try value.getValue(for: comp)
        }
        return value
    }

    func getValue(for component: JSONPath.Component) throws -> JSONValue {
        switch component {
        case .field(let name):
            let object = try asObject()
            guard let val = object[name] else {
                throw Error("Expected field named: \(name)")
            }
            return try JSONValue(val)
        case .array(let idx):
            let array = try asArray()
            guard array.indices.contains(idx) else {
                throw Error("Index out of bounds: \(idx)")
            }
            return try JSONValue(array[idx])
        }
    }

    public mutating func setValue(_ value: JSONValue, for path: String) throws {
        try setValue(value, for: JSONPath(parsing: path))
    }

    public mutating func setValue(_ value: JSONValue, for path: JSONPath) throws {
        try setValue(value, for: path.components)
    }

    mutating func setValue(_ value: JSONValue, for components: [JSONPath.Component]) throws {
        guard let comp = components.first else {
            self = value
            return
        }

        switch comp {
        case .field(let name):
            var object = try asObject()
            guard let val = object[name] else {
                throw Error("Expected field named: \(name)")
            }
            var new = try JSONValue(val)
            try new.setValue(value, for: Array(components.dropFirst()))
            object[name] = new
            self = .object(object)
        case .array(let idx):
            var array = try asArray()
            guard array.indices.contains(idx) else {
                throw Error("Index out of bounds: \(idx)")
            }
            var new = try JSONValue(array[idx])
            try new.setValue(value, for: Array(components.dropFirst()))
            array[idx] = new
            self = .array(array)
        }
    }
}

public extension JSONValue {

    init(data: Data) throws {
        try self.init(JSONSerialization.jsonObject(with: data, options: Self.defaultOptions))
    }

    func makeData(options: JSONSerialization.WritingOptions = []) throws -> Data {
        try JSONSerialization.data(withJSONObject: asAny(), options: options)
    }

    init(_ any: Any) throws {
        if let json = any as? JSONValue {
            self = json
        } else if let dict = any as? [String: Any] {
            self = try .object(dict.mapValues { try JSONValue($0) })
        } else if let array = any as? [Any] {
            self = try .array(array.map { try JSONValue($0) })
        } else if let string = any as? String {
            self = .string(string)
        } else if let nsNumber = any as? NSNumber {
            if type(of: nsNumber) == type(of: NSNumber(value: true)) {
                self = .boolean(nsNumber.boolValue)
            } else {
                self = .number(nsNumber.doubleValue)
            }
        } else if any is NSNull {
            self = .null
        } else if case nil as Any? = any {
            self = .null
        } else {
            throw Error("Unsupported Value")
        }
    }

    init<T>(_ any: T?) throws {
        switch any {
            case .none:
                self = .null
            case .some(let value):
                self = try JSONValue(value)
        }
    }

    func asAny() -> Any {
        switch self {
        case let .object(value):
            return value.mapValues { $0.asAny() }
        case let .array(value):
            return value.map { $0.asAny() }
        case let .string(value):
            return value
        case let .number(value):
            return value
        case let .boolean(value):
            return value
        case .null:
            return NSNull()
        }
    }

    private func asObject() throws -> [String: JSONValue] {
        guard case let .object(val) = self else {
            throw Error("Expected object")
        }
        return val
    }

    private func asArray() throws -> [JSONValue] {
        guard case let .array(val) = self else {
            throw Error("Expected array")
        }
        return val
    }

    private struct Error: LocalizedError {
        var errorDescription: String?

        init(_ description: String) {
            self.errorDescription = description
        }
    }

    private static var defaultOptions: JSONSerialization.ReadingOptions {
        guard #available(macOS 12.0, *) else { return [] }
        #if canImport(Darwin)
        return [.json5Allowed]
        #else
        return []
        #endif
    }
}

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .boolean(value)
    }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .number(Double(value))
    }
}

extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(value)
    }
}
