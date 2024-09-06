//
//  ProxyHTTPHandler.swift
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
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct ProxyHTTPHandler: HTTPHandler, Sendable {

    private let base: String
    private let session: URLSession
    private let timeout: TimeInterval?

    public init(base: String, session: URLSession = .shared, timeout: TimeInterval? = nil) {
        self.base = base
        self.session = session
        self.timeout = timeout
    }

    public func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        let req = try await makeURLRequest(for: request)
        let (data, response) = try await session.data(for: req)
        return makeResponse(for: response as! HTTPURLResponse, data: data)
    }

    func makeURLRequest(for request: HTTPRequest) async throws -> URLRequest {
        let url = try makeURL(for: request)
        var req = URLRequest(url: url)
        if let timeout {
            req.timeoutInterval = timeout
        }
        req.httpMethod = request.method.rawValue
        req.httpBody = try await request.bodyData
        req.allHTTPHeaderFields = request.headers.reduce(into: [:]) {
            if shouldForwardHeader($1.key) {
                $0![$1.key.rawValue] = $1.value
            }
        }
        return req
    }

    func shouldForwardHeader(_ header: HTTPHeader) -> Bool {
        let headers: Set<HTTPHeader> = [.host, .connection, .contentLength]
        return !headers.contains(header)
    }

    func makeURL(for request: HTTPRequest) throws -> URL {
        guard let base = URL(string: base).map( {$0.appendingPathComponent(request.path) }),
              var comps = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        if !request.query.isEmpty {
            comps.queryItems = request.query.map { URLQueryItem(name: $0.name, value: $0.value) }
        }
        return comps.url!
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
