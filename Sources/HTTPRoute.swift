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
//  https://github.com/swhitty/Awaiting
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


public struct HTTPRoute {
    public var components: [Component]

    public init(_ string: String) {
        self.components = string
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { Component(String($0)) }
    }

    public enum Component: Equatable {
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

    private func component(for index: Int) -> Component? {
        if components.indices.contains(index) {
            return components[index]
        } else if components.last == .wildcard {
            return .wildcard
        }
        return nil
    }

    private func patternMatch(to path: String) -> Bool {
        let nodes = path.split(separator: "/", omittingEmptySubsequences: true)
        for (idx, node) in nodes.enumerated() {
            guard let comp = component(for: idx), comp ~= String(node) else {
                return false
            }
        }

        return true
    }

    static func ~= (path: String, route: HTTPRoute) -> Bool {
        route.patternMatch(to: path)
    }

    static func ~= (route: HTTPRoute, path: String) -> Bool {
        route.patternMatch(to: path)
    }
}
