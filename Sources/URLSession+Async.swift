//
//  URLSession+Async.swift
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

extension URLSession {

    func makeRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if #available(macOS 12.0, iOS 13.0, *) {
            return try await data(for: request) as! (Data, HTTPURLResponse)
        } else {
            let continuation = Continuation()
            return try await withTaskCancellationHandler(
                operation: { try await continuation.data(for: request, using: self) },
                onCancel: continuation.cancel
            )
        }
    }

    private final class Continuation {

        private var dataTask: URLSessionDataTask?
        private var continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>?

        func data(for request: URLRequest, using session: URLSession) async throws -> (Data, HTTPURLResponse) {
            try await withCheckedThrowingContinuation { continuation in
                self.dataTask = session.dataTask(with: request) { data, response, error in
                    if let response = response as? HTTPURLResponse {
                        continuation.resume(returning:  (data ?? Data(), response))
                    } else {
                        continuation.resume(throwing: error ?? URLError(.unknown))
                    }
                }
                self.dataTask?.resume()
            }
        }

        @Sendable
        func cancel() {
            dataTask?.cancel()
        }
    }
}
