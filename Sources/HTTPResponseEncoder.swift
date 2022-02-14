//
//  HTTPResponseEncoder.swift
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

struct HTTPResponseEncoder {

    static func makeHeaderLines(from response: HTTPResponse, for request: HTTPRequest) -> [String] {
        let status = [response.version.rawValue,
                      String(response.statusCode.code),
                      response.statusCode.phrase].joined(separator: " ")

        var httpHeaders = response.headers

        if request.shouldKeepAlive {
            httpHeaders[.connection] = "keep-alive"
        }

        if response.body.isEmpty {
            httpHeaders[.contentLength] = nil
        } else {
            httpHeaders[.contentLength] = String(response.body.count)
        }

        let headers = httpHeaders.map { "\($0.key.rawValue): \($0.value)" }

        return [status] + headers + ["\r\n"]
    }

    static func encodeResponse(_ response: HTTPResponse, for request: HTTPRequest) throws -> Data {
        guard var data = makeHeaderLines(from: response, for: request)
                .joined(separator: "\r\n")
                .data(using: .utf8) else {
                    throw Error("Invalid Response Headers")
            }
        data.append(response.body)
        return data
    }
}

extension HTTPResponseEncoder {

    struct Error: LocalizedError {
        var errorDescription: String?

        init(_ description: String) {
            self.errorDescription = description
        }
    }
}
