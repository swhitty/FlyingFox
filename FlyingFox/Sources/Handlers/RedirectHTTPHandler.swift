//
//  RedirectHTTPHandler.swift
//  FlyingFox
//
//  Created by Simon Whitty on 15/02/2022.
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

public struct RedirectHTTPHandler: HTTPHandler {

    private let destination: Destination
    private let statusCode: HTTPStatusCode
    private let serverPath: String?

    public init(base: String, statusCode: HTTPStatusCode = .movedPermanently, serverPath: String? = nil) {
        self.destination = .base(base, serverPath: serverPath)
        self.statusCode = statusCode
        self.serverPath = serverPath
    }

    public init(location: String, statusCode: HTTPStatusCode = .movedPermanently) {
        self.destination = .location(location)
        self.statusCode = statusCode
        self.serverPath = nil
    }

    public func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        switch destination {
        case let .location(location):
            guard let url = URL(string: location) else {
                throw URLError(.badURL)
            }
            return try handleRedirect(to: url)
        case let .base(base, serverPath):
            let url = try makeRedirectLocation(for: request, via: base, serverPath: serverPath ?? "")
            return try handleRedirect(to: url)
        }
    }

    private enum Destination {
        case location(String)
        case base(String, serverPath: String?)
    }

    private func handleRedirect(to url: URL) throws -> HTTPResponse {
        guard Self.isRedirect(statusCode) else {
            throw URLError(.badURL)
        }
        return HTTPResponse(
            statusCode: statusCode,
            headers: [.location: url.absoluteString]
        )
    }

    private func makeRedirectLocation(for request: HTTPRequest, via base: String, serverPath: String) throws -> URL {
        guard let base = URL(string: base) else {
            throw URLError(.badURL)
        }

        let compsA = serverPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .joined(separator: "/")

        let compsB = request.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .joined(separator: "/")

        guard !compsA.isEmpty else {
            return try base.appendingRequest(request)
        }

        guard compsB.hasPrefix(compsA) else {
            throw URLError(.badURL)
        }

        var request = request
        request.path = String(compsB.dropFirst(compsA.count))
        return try base.appendingRequest(request)
    }

    static let redirectStatusCodes: Set<HTTPStatusCode> = [.movedPermanently, .found, .seeOther, .temporaryRedirect, .permanentRedirect]
    static func isRedirect(_ code: HTTPStatusCode) -> Bool {
        redirectStatusCodes.contains(code)
    }
}

private extension URL {

    func appendingRequest(_ request: HTTPRequest) throws -> URL {
        guard var comps = URLComponents(url: appendingPathComponent(request.path), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        var items = comps.queryItems ?? []
        items.append(
            contentsOf: request.query.map { URLQueryItem(name: $0.name, value: $0.value) }
        )

        if !items.isEmpty {
            comps.queryItems = items
        }

        guard let url = comps.url else {
            throw URLError(.badURL)
        }
        return url
    }
}
