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

public indirect enum JSONValue: @unchecked Sendable, Equatable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null

    public func getValue(for path: String) throws -> JSONValue {
        try getValue(for: JSONPath(parsing: path))
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
        } else if let int = any as? Int {
            self = .number(Double(int))
        } else if let double = any as? Double {
            self = .number(double)
        } else if let bool = any as? Bool {
            self = .boolean(bool)
        } else if any is NSNull {
            self = .null
        } else {
            throw Error("Unsupported Value")
        }
    }

    init?(_ value: JSONValue?) {
        guard let value else { return nil }
        self = value
    }

    init?(_ value: [String: JSONValue]?) {
        guard let value else { return nil }
        self = .object(value)
    }

    init?(_ value: [JSONValue]?) {
        guard let value else { return nil }
        self = .array(value)
    }

    init?(_ value: String?) {
        guard let value else { return nil }
        self = .string(value)
    }

    init?(_ value: Double?) {
        guard let value else { return nil }
        self = .number(value)
    }

    init?(_ value: Int?) {
        guard let value else { return nil }
        self = .number(Double(value))
    }

    init?(_ value: Bool?) {
        guard let value else { return nil }
        self = .boolean(value)
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

    func asObject() throws -> [String: JSONValue] {
        guard case let .object(val) = self else {
            throw Error("Expected object")
        }
        return val
    }

    func asArray() throws -> [JSONValue] {
        guard case let .array(val) = self else {
            throw Error("Expected array")
        }
        return val
    }

    func asString() throws -> String {
        guard case let .string(val) = self else {
            throw Error("Expected string")
        }
        return val
    }

    func asNumber() throws -> Double {
        guard case .number(let val) = self else {
            throw Error("Expected number")
        }
        return val
    }

    func asBool() throws -> Bool {
        switch self {
        case .boolean(let val):
            return val
        case .number(let val) where val == 0:
            return false
        case .number(let val) where val == 1:
            return true
        default:
            throw Error("Expected boolean")
        }
    }

    func asNull() throws -> NSNull {
        guard case .null = self else {
            throw Error("Expected null")
        }
        return NSNull()
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

public extension JSONValue {

    mutating func updateValue(parsing text: String) throws {
        if let null = try? Self.parseNull(string: text) {
            self = null
            return
        }
        switch self {
        case .object:
            self = try Self.parseObject(string: text)
        case .array:
            self = try Self.parseArray(string: text)
        case .string:
            self = .string(text)
        case .number:
            self = try Self.parseNumber(string: text)
        case .boolean:
            self = try Self.parseBoolean(string: text)
        case .null:
            self = Self.parseAny(string: text)
        }
    }

    static func parseObject(string: String) throws -> JSONValue {
        let data = string.data(using: .utf8)!
        guard case let .object(object) = try JSONValue(data: data) else {
            throw Error("Invalid object")
        }
        return .object(object)
    }

    static func parseArray(string: String) throws -> JSONValue {
        let data = string.data(using: .utf8)!
        guard case let .array(array) = try JSONValue(data: data) else {
            throw Error("Invalid array")
        }
        return .array(array)
    }

    static func parseNumber(string: String) throws -> JSONValue {
        guard let value = JSONValue.numberFormatter.number(from: string)?.doubleValue else {
            throw Error("Invalid number")
        }
        return .number(value)
    }

    static func parseBoolean(string: String) throws -> JSONValue {
        switch string.lowercased() {
        case "true":
            return .boolean(true)
        case "false":
            return .boolean(false)
        default:
            throw Error("Invalid boolean")
        }
    }

    static func parseNull(string: String) throws -> JSONValue {
        switch string.lowercased() {
        case "null", "":
            return .null
        default:
            throw Error("Invalid null")
        }
    }

    static func parseAny(string: String) -> JSONValue {
        if let object = try? parseObject(string: string) {
            return object
        } else if let array = try? parseArray(string: string) {
            return array
        } else if let number = try? parseNumber(string: string) {
            return number
        } else if let bool = try? parseBoolean(string: string) {
            return bool
        } else if let null = try? parseNull(string: string) {
            return null
        } else {
            return .string(string)
        }
    }
}

public extension JSONValue {
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        formatter.roundingMode = .halfUp
        return formatter
    }()
}
