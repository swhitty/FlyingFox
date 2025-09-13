//
//  HTTPDecoder.swift
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

import FlyingSocks
import Foundation

struct HTTPDecoder {

    var sharedRequestBufferSize: Int
    var sharedRequestReplaySize: Int

    func decodeRequest(from bytes: some AsyncBufferedSequence<UInt8>) async throws -> HTTPRequest {
        let status = try await bytes.lines.takeNext()
        let comps = status
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard comps.count == 3 else {
            throw Error("No HTTP Method")
        }

        let method = HTTPMethod(String(comps[0]))
        let version = HTTPVersion(String(comps[2]))
        let (path, query) = readComponents(from: String(comps[1]))

        let headers = try await readHeaders(from: bytes)
        let body = try await readBody(from: bytes, length: headers[.contentLength])

        return HTTPRequest(
            method: method,
            version: version,
            path: path,
            query: query,
            headers: HTTPHeaders(headers),
            body: body
        )
    }

    func decodeResponse(from bytes: some AsyncBufferedSequence<UInt8>) async throws -> HTTPResponse {
        let comps = try await bytes.lines.takeNext()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard comps.count == 3,
              let code = Int(comps[1]) else {
            throw Error("Invalid Status Line")
        }

        let version = HTTPVersion(String(comps[0]))
        let statusCode = HTTPStatusCode(code, phrase: String(comps[2]))

        let headers = try await readHeaders(from: bytes)
        let body = try await readBody(from: bytes, length: headers[.contentLength])

        return HTTPResponse(
            version: version,
            statusCode: statusCode,
            headers: HTTPHeaders(headers),
            body: try await body.get()
        )
    }

    func readComponents(from target: String) -> (path: String, query: [HTTPRequest.QueryItem]) {
        makeComponents(from: URLComponents(string: target))
    }

    func makeComponents(from comps: URLComponents?) -> (path: String, query: [HTTPRequest.QueryItem]) {
        let path = (comps?.percentEncodedPath).flatMap(HTTPDecoder.standardizePath) ?? ""
        let query = comps?.queryItems?.map {
            HTTPRequest.QueryItem(name: $0.name, value: $0.value ?? "")
        }
        return (path, query ?? [])
    }

    @Sendable
    func readHeader(from line: String) -> (header: HTTPHeader, value: String)? {
        let comps = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
        guard comps.count > 1 else { return nil }
        let name = comps[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = comps[1].trimmingCharacters(in: .whitespacesAndNewlines)
        return (HTTPHeader(name), value)
    }

    func readHeaders(from bytes: some AsyncBufferedSequence<UInt8>) async throws -> [HTTPHeader : String] {
        try await bytes
            .lines
            .prefix { $0 != "\r" && $0 != "" }
            .compactMap(readHeader)
            .reduce(into: [HTTPHeader: String]()) { $0[$1.header] = $1.value }
    }

    func readBody(from bytes: some AsyncBufferedSequence<UInt8>, length: String?) async throws -> HTTPBodySequence {
        let length = length.flatMap(Int.init) ?? 0
        guard sharedRequestBufferSize > 0 else {
            throw SocketError.disconnected
        }
        if length <= sharedRequestBufferSize {
            return try await HTTPBodySequence(data: readData(from: bytes, length: length), suggestedBufferSize: length)
        } else if length <= sharedRequestReplaySize {
            return HTTPBodySequence(shared: bytes, count: length, suggestedBufferSize: sharedRequestBufferSize)
        } else {
            let prefix = AsyncBufferedPrefixSequence(base: bytes, count: length)
            return HTTPBodySequence(from: prefix, count: length, suggestedBufferSize: sharedRequestBufferSize)
        }
    }

    private func readData(from bytes: some AsyncBufferedSequence<UInt8>, length: Int) async throws -> Data {
        var iterator = bytes.makeAsyncIterator()
        guard let buffer = try await iterator.nextBuffer(count: length),
              buffer.count == length else {
            throw SocketError.disconnected
        }
        return Data(buffer)
    }
}

extension HTTPDecoder {

    struct Error: LocalizedError {
        var errorDescription: String?

        init(_ description: String) {
            self.errorDescription = description
        }
    }
}

extension AsyncSequence where Element == UInt8 {

    // some AsyncSequence<String>
    var lines: AsyncThrowingMapSequence<CollectUntil<Self>, String> {
        collectStrings(separatedBy: "\n")
    }
}
