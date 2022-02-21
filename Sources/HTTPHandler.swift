//
//  HTTPHandler.swift
//  FlyingFox
//
//  Created by Simon Whitty on 14/02/2022.
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
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol HTTPHandler: Sendable {
    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse
}

public struct ClosureHTTPHandler: HTTPHandler {

    private let closure: @Sendable (HTTPRequest) async throws -> HTTPResponse

    public init(_ closure: @Sendable @escaping (HTTPRequest) async throws -> HTTPResponse) {
        self.closure = closure
    }

    public func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        try await closure(request)
    }
}

public struct RedirectHTTPHandler: HTTPHandler {

    private let location: String

    public init(location: String) {
        self.location = location
    }

    public func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let url = URL(string: location) else {
            throw URLError(.badURL)
        }
        return HTTPResponse(
            statusCode: .movedPermanently,
            headers: [.location: url.absoluteString]
        )
    }
}

public struct ProxyHTTPHandler: HTTPHandler, Sendable {

    private let base: String

    @UncheckedSendable
    private var session: URLSession

    public init(base: String, session: URLSession = .shared) {
        self.base = base
        self.session = session
    }

    public func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        let req = try makeURLRequest(for: request)
        let (data, response) = try await session.data(for: req)
        return makeResponse(for: response as! HTTPURLResponse, data: data)
    }

    func makeURLRequest(for request: HTTPRequest) throws -> URLRequest {
        let url = try makeURL(for: request)
        var req = URLRequest(url: url)
        req.httpMethod = request.method.rawValue
        req.httpBody = request.body
        req.allHTTPHeaderFields = request.headers.reduce(into: [:]) {
            if $1.key != .host {
                $0![$1.key.rawValue] = $1.value
            }
        }
        return req
    }

    func makeURL(for request: HTTPRequest) throws -> URL {
        guard let base = URL(string: base).map( {$0.appendingPathComponent(request.path) }),
              var comps = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        if !request.query.isEmpty {
            comps.queryItems = request.query.map { URLQueryItem(name: $0.name, value: $0.value) }
        }
        guard let url = comps.url else {
            throw URLError(.badURL)
        }
        return url
    }

    func makeResponse(for response: HTTPURLResponse, data: Data) -> HTTPResponse {
        var headers = [HTTPHeader: String]()
        for (name, value) in response.allHeaderFields {
            if let name = name as? String {
                headers[HTTPHeader(name)] = value as? String
            }
        }
        headers[.contentEncoding] = nil
        return HTTPResponse(statusCode: HTTPStatusCode(response.statusCode, phrase: ""),
                            headers: headers,
                            body: data)
    }
}

public struct FileHTTPHandler: HTTPHandler {

    @UncheckedSendable
    private var path: URL?
    private let contentType: String

    public init(path: URL, contentType: String) {
        self.path = path
        self.contentType = contentType
    }

    public init(named: String, in bundle: Bundle, contentType: String? = nil) {
        self.path = bundle.url(forResource: named, withExtension: nil)
        self.contentType = contentType ?? Self.makeContentType(for: named)
    }

    static func makeContentType(for filename: String) -> String {
        // TODO: UTTypeCreatePreferredIdentifierForTag / UTTypeCopyPreferredTagWithClass
        let pathExtension = (filename.lowercased() as NSString).pathExtension
        switch pathExtension {
        case "json":
            return "application/json"
        case "html", "htm":
            return "text/html"
        case "js", "javascript":
            return "application/javascript"
        default:
            return "application/octet-stream"
        }
    }

    public func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let path = path,
              let data = try? Data(contentsOf: path) else {
                  return HTTPResponse(statusCode: .notFound)
              }

        return HTTPResponse(statusCode: .ok,
                            headers: [.contentType: contentType],
                            body: data)
    }
}

public extension HTTPHandler where Self == FileHTTPHandler {
    static func file(named: String, in bundle: Bundle = .main) -> FileHTTPHandler {
        FileHTTPHandler(named: named, in: bundle)
    }
}

public extension HTTPHandler where Self == RedirectHTTPHandler {
    static func redirect(to location: String) -> RedirectHTTPHandler {
        RedirectHTTPHandler(location: location)
    }
}

public extension HTTPHandler where Self == ProxyHTTPHandler {
    static func proxy(via url: String) -> ProxyHTTPHandler {
        ProxyHTTPHandler(base: url)
    }
}
