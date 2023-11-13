//
//  FormDataSequence.swift
//  FlyingFox
//
//  Created by Simon Whitty on 09/11/2023.
//  Copyright © 2023 Simon Whitty. All rights reserved.
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

public extension HTTPRequest {

    var formDataSequence: FormDataSequence<HTTPBodySequence> {
        get async throws {
            let boundary = try HTTPDecoder.multipartFormDataBoundary(from: headers[.contentType])
            return try await FormDataSequence.make(body: bodySequence, boundary: boundary)
        }
    }
}

public struct FormDataSequence<S: AsyncSequence & Sendable>: Sendable, AsyncSequence where S.Element == Data {
    public typealias Element = FormData

    private let delimiter: DelimitedDataIterator<S.AsyncIterator>

    init(delimiter: DelimitedDataIterator<S.AsyncIterator>) {
        self.delimiter = delimiter
    }

    public static func make(body: S, boundary: String) async throws -> Self {
        var delimiter = DelimitedDataIterator(
            iterator: body.makeAsyncIterator(),
            delimiter: "\n--\(boundary)".data(using: .utf8)!
        )
        // consume first delimiter
        _ = try await delimiter.nextUntil("--\(boundary)".data(using: .utf8)!)
        try await delimiter.consumeNext(of: "\n", "--")
        return FormDataSequence(delimiter: delimiter)
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: delimiter)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {

        private var iterator: DelimitedDataIterator<S.AsyncIterator>

        init(iterator: DelimitedDataIterator<S.AsyncIterator>) {
            self.iterator = iterator
        }

        public mutating func next() async throws -> FormData? {
            let headers = try await iterator.parseHeaders()
            let data = try await iterator.next()

            guard let headers, let data else {
                // todo unexpected end without header
                return nil
            }

            // todo `--` end sequence
            try await iterator.consumeNext(of: "\n", "--")

            return FormData(
                headers: headers,
                body: data
            )
        }
    }
}

extension DelimitedDataIterator {

    mutating func consumeNext(of strings: String...) async throws {
        for match in strings {
            if try await next(of: match.data(using: .utf8)!) != nil {
                return
            }
        }
        throw AsyncSequenceError("No Match")
    }

    mutating func nextLine() async throws -> String? {
        guard let data = try await nextUntil("\n".data(using: .utf8)!) else {
            return nil
        }
        return String(data: data, encoding: .utf8)!
    }

    mutating func parseHeaders() async throws -> [FormHeader: String]? {
        var headers = [FormHeader: String]()
        var started = false

        while let line = try await nextLine() {
            started = true
            if line.isEmpty { break }
            if let header = HTTPDecoder.readHeader(from: line) {
                headers[FormHeader(header.header.rawValue)] = header.value
            }
        }

        return started ? headers : nil
    }
}
