//
//  HTTPResponse+Mock.swift
//  FlyingFox
//
//  Created by Simon Whitty on 17/02/2022.
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

@testable import FlyingFox
import Foundation

extension HTTPResponse {

    static func make(version: HTTPVersion = .http11,
                     statusCode: HTTPStatusCode  = .ok,
                     headers: [HTTPHeader: String] = [:],
                     body: Data = Data()) -> Self {
        HTTPResponse(version: version,
                     statusCode: statusCode,
                     headers: headers,
                     body: body)
    }

#if compiler(>=5.9)
    static func makeChunked(version: HTTPVersion = .http11,
                            statusCode: HTTPStatusCode  = .ok,
                            headers: [HTTPHeader: String] = [:],
                            body: Data = Data(),
                            chunkSize: Int = 5) -> Self {
        let consuming = ConsumingAsyncSequence(body)
        return HTTPResponse(
            version: version,
            statusCode: statusCode,
            headers: headers,
            body: HTTPBodySequence(from: consuming, bufferSize: chunkSize)
        )
    }
#endif

    static func make(version: HTTPVersion = .http11,
                     statusCode: HTTPStatusCode  = .ok,
                     headers: [HTTPHeader: String] = [:],
                     body: HTTPBodySequence) -> Self {
        HTTPResponse(version: version,
                     statusCode: statusCode,
                     headers: headers,
                     body: body)
    }

    static func make(headers: [HTTPHeader: String] = [:],
                     webSocket handler: some WSHandler) -> Self {
        HTTPResponse(headers: headers,
                     webSocket: handler)
    }
}
