//
//  CompositeHTTPHandler.swift
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

public struct CompositeHTTPHandler: HTTPHandler, Sendable {

    private var handlers: [(route: HTTPRoute, handler: HTTPHandler)] = []

    public mutating func appendHandler(for route: HTTPRoute, handler: HTTPHandler) {
        handlers.append((route, handler))
    }

    public mutating func appendHandler(for route: HTTPRoute,
                                       closure: @Sendable @escaping (HTTPRequest) async throws -> HTTPResponse) {
        handlers.append((route, ClosureHTTPHandler(closure)))
    }

    public func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        for entry in handlers where entry.route ~= request {
            do {
                return try await entry.handler.handleRequest(request)
            } catch is HTTPUnhandledError {
                continue
            } catch {
                throw error
            }
        }
        throw HTTPUnhandledError()
    }
}
