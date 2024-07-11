//
//  RoutedHTTPHandler.swift
//  FlyingFox
//
//  Created by Simon Whitty on 25/02/2022.
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

public struct RoutedHTTPHandler: HTTPHandler, Sendable {

    private var handlers: [(route: HTTPRoute, handler: any HTTPHandler)] = []

    public init() { }

    public mutating func appendRoute(_ route: HTTPRoute, to handler: some HTTPHandler) {
        append((route, handler))
    }

    public mutating func appendRoute(_ route: HTTPRoute,
                                     handler: @Sendable @escaping (HTTPRequest) async throws -> HTTPResponse) {
        append((route, ClosureHTTPHandler(handler)))
    }

    public mutating func insertRoute(_ route: HTTPRoute, 
                                     at index: Index,
                                     to handler: some HTTPHandler) {
        insert((route, handler), at: index)
    }

    public mutating func insertRoute(_ route: HTTPRoute,
                                     at index: Index,
                                     handler: @Sendable @escaping (HTTPRequest) async throws -> HTTPResponse) {
        insert((route, ClosureHTTPHandler(handler)), at: index)
    }

    public func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        for entry in handlers  {
            do {
                if await entry.route ~= request {
                    return try await HTTPRequest.$matchedRoute.withValue(entry.route) {
                        return try await entry.handler.handleRequest(request)
                    }
                }
            } catch is HTTPUnhandledError {
                continue
            } catch {
                throw error
            }
        }
        throw HTTPUnhandledError()
    }
}

public extension RoutedHTTPHandler {
    mutating func appendRoute(
        _ path: String,
        for methods: some Sequence<HTTPMethod>,
        to handler: some HTTPHandler
    ) {
        let route = HTTPRoute(methods: methods, path: path)
        appendRoute(route, to: handler)
    }

    mutating func appendRoute(
        _ path: String,
        for methods: some Sequence<HTTPMethod>,
        handler: @Sendable @escaping (HTTPRequest) async throws -> HTTPResponse
    ) {
        let route = HTTPRoute(methods: methods, path: path)
        appendRoute(route, handler: handler)
    }

    mutating func insertRoute(
        _ path: String,
        for methods: some Sequence<HTTPMethod>,
        at index: Index,
        to handler: some HTTPHandler
    ) {
        let route = HTTPRoute(methods: methods, path: path)
        insertRoute(route, at: index, to: handler)
    }

    mutating func insertRoute(
        _ path: String,
        for methods: some Sequence<HTTPMethod>,
        at index: Index,
        handler: @Sendable @escaping (HTTPRequest) async throws -> HTTPResponse
    ) {
        let route = HTTPRoute(methods: methods, path: path)
        insertRoute(route, at: index, handler: handler)
    }
}

extension RoutedHTTPHandler: RangeReplaceableCollection {
    public typealias Index = Array<Element>.Index
    public typealias Element = (route: HTTPRoute, handler: any HTTPHandler)

    public var startIndex: Index { handlers.startIndex }
    public var endIndex: Index { handlers.endIndex }

    public subscript(index: Index) -> Element {
        get { handlers[index] }
        set { handlers[index] = newValue }
    }

    public func index(after i: Index) -> Index {
        handlers.index(after: i)
    }

    public mutating func replaceSubrange(_ subrange: Range<Index>, with newElements: some Collection<Element>) {
        handlers.replaceSubrange(subrange, with: newElements)
    }
}
