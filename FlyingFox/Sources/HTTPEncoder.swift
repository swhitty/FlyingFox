//
//  HTTPEncoder.swift
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

struct HTTPEncoder {

    static func makeHeaderLines(from response: HTTPResponse) -> [String] {
        let status = [response.version.rawValue,
                      String(response.statusCode.code),
                      response.statusCode.phrase].joined(separator: " ")

        var httpHeaders = response.headers
        if let contentLength = makeContentLength(from: response.payload) {
            httpHeaders[.contentLength] = String(contentLength)
        } else if let encoding = makeTransferEncoding(from: response.payload) {
            httpHeaders.addValue(encoding, for: .transferEncoding)
        }

        let headers = httpHeaders.map { "\($0.key.rawValue): \($0.value)" }

        return [status] + headers + ["\r\n"]
    }

    static func makeContentLength(from payload: HTTPResponse.Payload) -> Int? {
        switch payload {
        case .httpBody(let sequence):
            return sequence.count
        case .webSocket:
            return nil
        }
    }

    static func makeTransferEncoding(from payload: HTTPResponse.Payload) -> String? {
        switch payload {
        case .httpBody(let sequence) where sequence.count == nil:
            return "chunked"
        default:
            return nil
        }
    }

    static func encodeResponseHeader(_ response: HTTPResponse) -> Data {
        makeHeaderLines(from: response)
            .joined(separator: "\r\n")
            .data(using: .utf8)!
    }

    static func makeHeaderLines(from request: HTTPRequest) -> [String] {
        let status = [request.method.rawValue,
                      makePercentEncoded(from: request),
                      request.version.rawValue].joined(separator: " ")

        var httpHeaders = request.headers
        httpHeaders[.contentLength] = String(request.bodySequence.count ?? 0)
        let headers = httpHeaders.map { "\($0.key.rawValue): \($0.value)" }

        return [status] + headers + ["\r\n"]
    }

    static func makePercentEncoded(from request: HTTPRequest) -> String {
        var comps = URLComponents()
        comps.path = request.path
        comps.queryItems = request.query.map { URLQueryItem(name: $0.name, value: $0.value) }
        guard let query = comps.percentEncodedQuery, !query.isEmpty else {
            return comps.percentEncodedPath
        }
        return "\(comps.percentEncodedPath)?\(query)"
    }

    static func encodeRequest(_ request: HTTPRequest) async throws -> Data {
        var data = makeHeaderLines(from: request)
            .joined(separator: "\r\n")
            .data(using: .utf8)!

        try await data.append(request.bodyData)

        return data
    }
}
