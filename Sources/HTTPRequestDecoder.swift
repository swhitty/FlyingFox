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

    static func decodeRequest<S>(from bytes: S) async throws -> HTTPRequest where S: AsyncSequence, S.Element == UInt8 {
        let status = try await bytes.takeLine()
        let comps = status.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard comps.count == 3, !comps[0].isEmpty else {
            throw Error("No HTTP Method")
        }

        let method = HTTPMethod(rawValue: String(comps[0]))
        let version = HTTPVersion(rawValue: String(comps[2]))
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

    static func readComponents(from target: String) -> (path: String, query: [(name: String, value: String)]) {
        let comps = URLComponents(string: target)
        let path = comps?.path ?? ""
        let query = comps?.queryItems?.map { ($0.name, $0.value ?? "") }
        return (path, query ?? [])
    }

    static func readHeader(from line: String) -> (header: HTTPHeader, value: String)? {
        let comps = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
        guard comps.count > 1 else { return nil }
        let name = comps[0].trimmingCharacters(in: .whitespaces)
        let value = comps[1].trimmingCharacters(in: .whitespaces)
        return (HTTPHeader(rawValue: name), value)
    }

    static func readBody<S: AsyncSequence>(from bytes: S, length: String?) async throws -> Data where S.Element == UInt8 {
        guard let length = length.flatMap(Int.init) else {
            return Data()
        }

        return try await bytes
            .collectUntil { $0.count == length }
            .map { Data($0) }
            .first()
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
