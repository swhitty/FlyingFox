//
//  HTTPRoute.swift
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

import Foundation


public struct HTTPRoute: Sendable {
    public var method: Component
    public var path: [Component]

    public init(_ string: String) {
        let comps = Self.components(for: string)
        self.init(method: comps.method, path: comps.path)
    }

    public init(method: HTTPMethod, path: String) {
        self.init(method: method.rawValue, path: path)
    }

    init(method: String, path: String) {
        self.method = Component(method)
        self.path = path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { Component(String($0)) }
    }

    public enum Component: Equatable, Sendable {
        case wildcard
        case caseInsensitive(String)

        public init(_ string: String) {
            switch string {
            case "*":
                self = .wildcard
            default:
                self = .caseInsensitive(string)
            }
        }
    }
}

public extension HTTPRoute.Component {

    private func patternMatch(to node: String) -> Bool {
        switch self {
        case .wildcard:
            return true
        case .caseInsensitive(let text):
            return node.caseInsensitiveCompare(text) == .orderedSame
        }
    }

    static func ~= (component: HTTPRoute.Component, node: String) -> Bool {
        component.patternMatch(to: node)
    }
}


public extension HTTPRoute {

    private func pathComponent(for index: Int) -> Component? {
        if path.indices.contains(index) {
            return path[index]
        } else if path.last == .wildcard {
            return .wildcard
        }
        return nil
    }

    private func patternMatch(method: String, path: String) -> Bool {
        let nodes = path.split(separator: "/", omittingEmptySubsequences: true)
        guard self.method ~= method else {
            return false
        }
        guard nodes.count >= self.path.count else {
            return nodes.isEmpty && self.path.first == .wildcard
        }

        for (idx, node) in nodes.enumerated() {
            guard let comp = pathComponent(for: idx), comp ~= String(node) else {
                return false
            }
        }

        return true
    }

    private static func components(for target: String) -> (method: String, path: String) {
        let comps = target.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard comps.count > 1 else {
            return (method: "*", path: target)
        }
        return (method: String(comps[0]), path: String(comps[1]))
    }

    @available(*, deprecated, message: "Pattern match against HTTPRequest instead")
    static func ~= (route: HTTPRoute, target: String) -> Bool {
        let comps = HTTPRoute.components(for: target)
        return route.patternMatch(method: comps.method, path: comps.path)
    }

    static func ~= (route: HTTPRoute, request: HTTPRequest) -> Bool {
        route.patternMatch(method: request.method.rawValue, path: request.path)
    }

}

extension HTTPRoute: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        self.init(value)
    }
}
