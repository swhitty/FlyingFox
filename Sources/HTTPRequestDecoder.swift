//
//  HTTPRequestDecoder.swift
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

struct HTTPRequestDecoder {

    static func decodeRequest<S>(from bytes: S) async throws -> HTTPRequest where S: ChuckedAsyncSequence, S.Element == UInt8 {
        let status = try await bytes.takeLine()
        let comps = status
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard comps.count == 3 else {
            throw Error("No HTTP Method")
        }

        let method = HTTPMethod(String(comps[0]))
        let version = HTTPVersion(String(comps[2]))
        let (path, query) = Self.readComponents(from: String(comps[1]))

        let headers = try await bytes
            .lines
            .prefix { $0 != "\r" && $0 != "" }
            .compactMap(Self.readHeader)
            .reduce(into: [HTTPHeader: String]()) { $0[$1.header] = $1.value }

        let body = try await Self.readBody(from: bytes, length: headers[.contentLength])

        return HTTPRequest(
            method: method,
            version: version,
            path: path,
            query: query,
            headers: headers,
            body: body
        )
    }

    static func readComponents(from target: String) -> (path: String, query: [HTTPRequest.QueryItem]) {
        let comps = URLComponents(string: target)
        let path = comps?.path ?? ""
        let query = comps?.queryItems?.map {
            HTTPRequest.QueryItem(name: $0.name,
                                  value: $0.value ?? "")
        }
        return (path, query ?? [])
    }

    static func readHeader(from line: String) -> (header: HTTPHeader, value: String)? {
        let comps = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
        guard comps.count > 1 else { return nil }
        let name = comps[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = comps[1].trimmingCharacters(in: .whitespacesAndNewlines)
        return (HTTPHeader(name), value)
    }

    static func readBody<S: ChuckedAsyncSequence>(from bytes: S, length: String?) async throws -> Data where S.Element == UInt8 {
        guard let length = length.flatMap(Int.init) else {
            return Data()
        }

        guard let buffer = try await bytes.next(count: length) else {
            throw Error("ChuckedAsyncSequence prematurely ended")
        }

        return Data(buffer)
    }
}

extension HTTPRequestDecoder {

    struct Error: LocalizedError {
        var errorDescription: String?

        init(_ description: String) {
            self.errorDescription = description
        }
    }
}


private extension AsyncSequence where Element == UInt8 {

    var lines: AsyncThrowingMapSequence<CollectUntil<Self>, String> {
        collectStrings(separatedBy: "\n")
    }

    func takeLine() async throws -> String {
        try await lines.first()
    }
}
