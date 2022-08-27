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
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import FlyingSocks

@available(iOS, deprecated: 15.0, message: "use data(for request: URLRequest) directly")
@available(tvOS, deprecated: 15.0, message: "use data(for request: URLRequest) directly")
@available(macOS, deprecated: 12.0, message: "use data(for request: URLRequest) directly")
extension URLSession {

    func getData(for request: URLRequest, forceFallback: Bool = false) async throws -> (Data, URLResponse) {
        guard !forceFallback, #available(macOS 12.0, iOS 15.0, tvOS 15.0, *) else {
            return try await makeData(for: request)
        }
#if canImport(FoundationNetworking)
        return try await makeData(for: request)
#else
        return try await data(for: request, delegate: nil)
#endif
    }

    func makeData(for request: URLRequest) async throws -> (Data, URLResponse) {
        let continuation = CancellingContinuation<(Data, URLResponse), Error>()
        let task = dataTask(with: request) { data, response, error in
            guard let data = data, let response = response else {
                continuation.resume(throwing: error!)
                return
            }
            continuation.resume(returning: (data, response))
        }
        defer { task.cancel() }
        task.resume()

        do {
            return try await continuation.value
        } catch is CancellationError {
            throw URLError(.cancelled)
        } catch {
            throw error
        }
    }
}
