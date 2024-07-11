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
    public var methods: Set<HTTPMethod>
    public var path: [Component]
    public var query: [QueryItem]
    public var headers: [HTTPHeader: Component]
    public var body: (any HTTPBodyPattern)?

    public init(
        methods: Set<HTTPMethod>,
        path: String,
        headers: [HTTPHeader: String] = [:],
        body: (any HTTPBodyPattern)? = nil
    ) {
        self.methods = methods

        let comps = HTTPRoute.readComponents(from: path)
        self.path = comps.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { Component(String($0)) }
        self.query = comps.query.map {
            QueryItem(name: $0.name, value: Component($0.value))
        }
        self.headers = headers.mapValues(Component.init)
        self.body = body
    }

    init(methods: String, path: String, headers: [HTTPHeader: String], body: (any HTTPBodyPattern)?) {
        self.methods = Self.methods(for: methods)

        let comps = HTTPRoute.readComponents(from: path)
        self.path = comps.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { Component(String($0)) }
        self.query = comps.query.map {
            QueryItem(name: $0.name, value: Component($0.value))
        }
        self.headers = headers.mapValues(Component.init)
        self.body = body
    }

    public enum Component: Sendable, Equatable {
        case wildcard
        case caseInsensitive(String)
        case parameter(String)

        public init(_ string: String) {
            switch string {
            case "*":
                self = .wildcard
            default:
                if string.hasPrefix(":") {
                    let name = String(string.dropFirst())
                    self = .parameter(name)
                } else {
                    self = .caseInsensitive(string)
                }
            }
        }
    }

    // MARK: Convenience Initializers

    public init(
        methods: some Sequence<HTTPMethod>,
        path: String,
        headers: [HTTPHeader: String] = [:],
        body: (any HTTPBodyPattern)? = nil
    ) {
        self.init(
            methods: Set(methods),
            path: path,
            headers: headers,
            body: body
        )
    }

    public init(
        method: HTTPMethod,
        path: String,
        headers: [HTTPHeader: String] = [:],
        body: (any HTTPBodyPattern)? = nil
    ) {
        self.init(
            methods: [method],
            path: path,
            headers: headers,
            body: body
        )
    }

    public init(
        _ string: String,
        headers: [HTTPHeader: String] = [:],
        body: (any HTTPBodyPattern)? = nil
    ) {
        let comps = Self.components(for: string)
        self.init(
            methods: comps.methods,
            path: comps.path,
            headers: headers,
            body: body
        )
    }

    public struct QueryItem: Sendable, Equatable {
        public var name: String
        public var value: Component

        public init(name: String, value: Component) {
            self.name = name
            self.value = value
        }

        public static func ~= (item: QueryItem, requestItem: HTTPRequest.QueryItem) -> Bool {
            item.name == requestItem.name && item.value ~= requestItem.value
        }
    }

    @available(*, deprecated, renamed: "methods", message: "Use ``methods`` instead")
    public var method: Component {
        if methods == HTTPMethod.allMethods {
            return .wildcard
        } else {
            let firstMethod = HTTPMethod.sortedMethods
                .filter { methods.contains($0) }
                .first!
                .rawValue
            return .caseInsensitive(firstMethod)
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
        case .parameter:
            return true
        }
    }

    static func ~= (component: HTTPRoute.Component, node: String?) -> Bool {
        guard let node = node else { return false }
        return component.patternMatch(to: node)
    }

    static func ~= (component: HTTPRoute.Component, nodes: [String]) -> Bool {
        nodes.contains { component.patternMatch(to: $0) }
    }
}

public extension HTTPRoute {

    var pathParameters: [String: Int] {
        path.enumerated().reduce(into: [:]) { partialResult, item in
            switch item.element {
                case let .parameter(name):
                    partialResult[name] = item.offset
                case .caseInsensitive,
                     .wildcard:
                    break
            }
        }
    }

    func pathComponent(for index: Int) -> Component? {
        if path.indices.contains(index) {
            return path[index]
        } else if path.last == .wildcard {
            return .wildcard
        }
        return nil
    }

    private func patternMatch(request: HTTPRequest) async -> Bool {
        guard patternMatch(query: request.query),
              patternMatch(headers: request.headers),
              await patternMatch(body: request.bodySequence) else { return false }

        let nodes = request.path.split(separator: "/", omittingEmptySubsequences: true)
        guard self.methods.contains(request.method) else {
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

    private func patternMatch(query items: [HTTPRequest.QueryItem]) -> Bool {
        for routeItem in query {
            guard let _ = items.first(where: { routeItem ~= $0 }) else {
                return false
            }
        }
        return true
    }

    private func patternMatch(headers request: [HTTPHeader: String]) -> Bool {
        return headers.allSatisfy { header, value in
            value ~= request.values(for: header)
        }
    }

    private func patternMatch(body request: HTTPBodySequence) async -> Bool {
        guard let body = body else { return true }

        guard request.canReplay else {
            // body is large and can only be iterated one-time only so should not match it
            return false
        }

        do {
            return try await body.evaluate(request.get())
        } catch {
            return false
        }
    }

    private static func components(for target: String) -> (
        methods: Set<HTTPMethod>,
        path: String
    ) {
        let comps = target.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard comps.count > 1 && !comps[0].hasPrefix("/") else {
            return (methods: HTTPMethod.allMethods, path: target)
        }
        
        let methods = methods(for: comps[0])
        return (methods: methods, path: String(comps[1]))
    }

    private static func methods(for target: any StringProtocol) -> Set<HTTPMethod> {
        // The following formats of the method component are valid:
        // "" (empty)
        // "GET" (a single method)
        // "GET,POST" (comma-delimited list)
        var methods: Set<HTTPMethod> = target.split(
            separator: ",",
            omittingEmptySubsequences: true
        )
            .map { HTTPMethod(stringLiteral: String($0)) }
            .reduce(into: []) { partialResult, method in
                partialResult.insert(method)
            }

        // If there are no methods, ensure that we support all methods.
        if methods.isEmpty {
            methods.formUnion(HTTPMethod.allMethods)
        }

        return methods
    }

    @available(*, unavailable, message: "renamed: ~= async")
    static func ~= (route: HTTPRoute, request: HTTPRequest) -> Bool {
        fatalError()
    }

    static func ~= (route: HTTPRoute, request: HTTPRequest) async -> Bool {
        await route.patternMatch(request: request)
    }
}

private extension HTTPRoute {

    static func readComponents(from path: String) -> (path: String, query: [HTTPRequest.QueryItem]) {
        guard path.removingPercentEncoding == path else {
            return HTTPDecoder.readComponents(from: path)
        }

        let escaped = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        return HTTPDecoder.readComponents(from: escaped ?? path)
    }
}

extension HTTPRoute: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        self.init(value)
    }
}
