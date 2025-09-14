//
//  HTTPRoute+withRoute.swift
//  FlyingFox
//
//  Created by Simon Whitty on 15/09/2025.
//  Copyright © 2025 Simon Whitty. All rights reserved.
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

#if compiler(>=6.2)
public func withRoute<T, Failure: Error>(
    _ route: HTTPRoute,
    matching request: HTTPRequest,
    execute body: () async throws(Failure) -> T
) async throws(Failure) -> T? {
    guard await route ~= request else { return nil }
    do {
        return try await HTTPRequest.$matchedRoute.withValue(route) {
            return try await body()
        }
    } catch let error as Failure {
        throw error
    } catch {
        preconditionFailure("cannot occur")
    }
}
#elseif compiler(>=6.0)
import struct FlyingSocks.Transferring

public func withRoute<T, Failure: Error>(
    isolation: isolated (any Actor)? = #isolation,
    _ route: HTTPRoute,
    matching request: HTTPRequest,
    execute body: () async throws(Failure) -> sending T
) async throws(Failure) -> sending T? {
    guard await route ~= request else { return nil }
    do {
        nonisolated(unsafe) let body = body
        return try await HTTPRequest.$matchedRoute.withValue(route) {
            _ = isolation
            return try await Transferring(body())
        }.value
    } catch let error as Failure {
        throw error
    } catch {
        preconditionFailure("cannot occur")
    }
}
#endif
