//
//  BasicAuthRoutedHTTPHandler.swift
//  FlyingFox
//
//  Created by Simon Whitty on 27/09/2024.
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

public struct BasicAuthRoutedHTTPHandler: HTTPHandler, Sendable {

    private var handlers = RoutedHTTPHandler()
    private var realm: String
    private var username: String
    private var password: String

    public init(realm: String, username: String, password: String) {
        self.realm = realm
        self.username = username
        self.password = password
    }

    public mutating func appendRoute(_ route: HTTPRoute, to handler: some HTTPHandler) {
        handlers.appendRoute(route, to: handler)
    }

    public mutating func appendRoute(_ route: HTTPRoute,
                                     handler: @Sendable @escaping (HTTPRequest) async throws -> HTTPResponse) {
        handlers.appendRoute(route, handler: handler)
    }

    public mutating func appendRoute<each P: HTTPRouteParameterValue>(
        _ route: HTTPRoute,
        handler: @Sendable @escaping (HTTPRequest, repeat each P) async throws -> HTTPResponse
    ) {
        handlers.appendRoute(route, handler: handler)
    }

    public mutating func appendRoute<each P: HTTPRouteParameterValue>(
        _ route: HTTPRoute,
        handler: @Sendable @escaping (repeat each P) async throws -> HTTPResponse
    ) {
        handlers.appendRoute(route, handler: handler)
    }

    public func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let credentials = request.basicAuthorization else {
            return HTTPResponse(statusCode: .unauthorized, headers: [.wwwAuthenticate: "Basic realm=\"\(realm)\""])
        }
        guard credentials.username == username, credentials.password == password else {
            return HTTPResponse(statusCode: .forbidden)
        }
        return try await handlers.handleRequest(request)
    }
}

extension HTTPRequest {

    var basicAuthorization: (username: String, password: String)? {
        let auth = headers[.authorization] ?? ""
        let comps = auth.components(separatedBy: " ")
        guard comps.count == 2, comps[0] == "Basic" else {
            return nil
        }
        guard let data = Data(base64Encoded: comps[1]),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        let parts = text.components(separatedBy: ":")
        guard parts.count == 2 else {
            return nil
        }
        return (username: parts[0], password: parts[1])
    }

}
