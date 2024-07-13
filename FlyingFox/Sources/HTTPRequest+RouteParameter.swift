//
//  HTTPRequest+RouteParameter.swift
//  FlyingFox
//
//  Created by Simon Whitty on 13/07/2024.
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

public extension HTTPRequest {

    struct RouteParameter: Sendable, Hashable {
        public var name: String
        public var value: String

        public init(name: String, value: String) {
            self.name = name
            self.value = value
        }
    }

    /// Values extracted from the matched route and request
    var routeParameters: [RouteParameter] { routeParameters() }
}

extension HTTPRequest {

    func routeParameters(for route: HTTPRoute? = matchedRoute) -> [RouteParameter] {
        guard let route else { return [] }

        let pathComponents = path
            .split(separator: "/", omittingEmptySubsequences: true)

        return route.parameters
            .compactMap {
                switch $0 {
                case let .path(name: name, index: index):
                    if pathComponents.indices.contains(index) {
                        return RouteParameter(name: name, value: String(pathComponents[index]))
                    } else {
                        return nil
                    }
                case let .query(name: name, index: index):
                    if let value = query[index] {
                        return RouteParameter(name: name, value: value)
                    } else {
                        return nil
                    }
                }
            }
    }

}

public extension Array where Element == HTTPRequest.RouteParameter {

    subscript(_ name: String) -> String? {
        get {
            first { $0.name == name }?.value
        }
    }
}
