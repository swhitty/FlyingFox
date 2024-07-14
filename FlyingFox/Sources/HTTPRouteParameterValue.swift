//
//  HTTPRequestParameter.swift
//  FlyingFox
//
//  Created by Simon Whitty on 11/07/2024.
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

import Foundation

/// Converts values from `HTTPRoute.Parameter` with `HTTPRequest`
public protocol HTTPRouteParameterValue {
    init(parameter: String) throws
}

extension String: HTTPRouteParameterValue {
    public init(parameter: String) {
        self.init(parameter)
    }
}

extension Int: HTTPRouteParameterValue { }
extension Int64: HTTPRouteParameterValue { }
extension Int32: HTTPRouteParameterValue { }
extension Int16: HTTPRouteParameterValue { }
extension Int8: HTTPRouteParameterValue { }
extension UInt: HTTPRouteParameterValue { }
extension UInt64: HTTPRouteParameterValue { }
extension UInt32: HTTPRouteParameterValue { }
extension UInt16: HTTPRouteParameterValue { }
extension UInt8: HTTPRouteParameterValue { }

public extension HTTPRouteParameterValue where Self: BinaryInteger {
    init(parameter: String) throws {
        guard let int64 = Int64(parameter),
        let value = Self(exactly: int64) else {
            throw HTTPRouteParameterInvalid()
        }
        self = value
    }
}

extension Double: HTTPRouteParameterValue {
    public init(parameter: String) throws {
        guard let value = Self(parameter) else {
            throw HTTPRouteParameterInvalid()
        }
        self = value
    }
}

extension Float32: HTTPRouteParameterValue {
    public init(parameter: String) throws {
        guard let value = Self(parameter) else {
            throw HTTPRouteParameterInvalid()
        }
        self = value
    }
}

extension Bool: HTTPRouteParameterValue {
    public init(parameter: String) throws {
        switch parameter.lowercased() {
        case "true":
            self = true
        case "false":
            self = false
        default:
            throw HTTPRouteParameterInvalid()
        }
    }
}

public extension HTTPRouteParameterValue where Self: RawRepresentable, RawValue: HTTPRouteParameterValue {
    init(parameter: String) throws {
        let rawValue = try RawValue(parameter: parameter)
        guard let value = Self(rawValue: rawValue)else {
            throw HTTPRouteParameterInvalid()
        }
        self = value
    }
}

public struct HTTPRouteParameterInvalid: Error { }

public extension HTTPRoute {

    func extractParameters(from request: HTTPRequest) -> [HTTPRequest.RouteParameter] {
        let pathComponents = request.path
            .split(separator: "/", omittingEmptySubsequences: true)

        return parameters
            .compactMap {
                switch $0 {
                case let .path(name: name, index: index):
                    if pathComponents.indices.contains(index) {
                        return HTTPRequest.RouteParameter(
                            name: name,
                            value: String(pathComponents[index])
                        )
                    } else {
                        return nil
                    }
                case let .query(name: name, index: index):
                    if let value = request.query[index] {
                        return HTTPRequest.RouteParameter(
                            name: name,
                            value: value
                        )
                    } else {
                        return nil
                    }
                }
            }
    }
}

extension HTTPRoute {

    func extractParameterValues<each P: HTTPRouteParameterValue>(
        of type: (repeat each P).Type = (repeat each P).self,
        from request: HTTPRequest
    ) throws -> (repeat each P) {
        let parameters = extractParameters(from: request).map(\.value)
        var idx = 0
        return try (repeat extractValue(of: (each P).self, at: &idx, from: parameters))
    }

    private func extractValue<P: HTTPRouteParameterValue>(
        of type: P.Type,
        at index: inout Int,
        from parameters: [String]
    ) throws -> P {
        defer { index += 1 }

        guard parameters.indices.contains(index) else {
            throw HTTPRouteParameterInvalid()
        }

        return try P(parameter: parameters[index])
    }
}
