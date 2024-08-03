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
import FlyingSocks

#if canImport(FoundationNetworking)
import FoundationNetworking

extension URLSession {

    // Ports macOS Foundation method to Linux
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let state = AllocatedLock(initialState: (isCancelled: false, task: URLSessionDataTask?.none))
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = dataTask(with: request) { data, response, error in
                    guard let data = data, let response = response else {
                        continuation.resume(throwing: error!)
                        return
                    }
                    continuation.resume(returning: (data, response))
                }
                let shouldCancel = state.withLock {
                    $0.task = task
                    return $0.isCancelled
                }
                task.resume()
                if shouldCancel {
                    task.cancel()
                }
            }
        } onCancel: {
            let taskToCancel = state.withLock {
                $0.isCancelled = true
                return $0.task
            }
            if let taskToCancel {
                taskToCancel.cancel()
            }
        }
    }
}
#endif
