//
//  HTTPConnectionTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 22/02/2022.
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
import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class HTTPConnectionTests: XCTestCase {

    let pool: AsyncSocketPool = PollingSocketPool()
    var task: Task<Void, Error>?

    override func setUp() {
        task = Task { try await pool.run() }
    }

    override func tearDown() {
        task?.cancel()
    }

    func testConnection_ReceivesRequest() async throws {
        let (s1, s2) = try AsyncSocket.makePair(pool: pool)

        let connection = HTTPConnection(socket: s1)
        try await s2.writeString(
            """
            GET /hello/world HTTP/1.1\r
            \r

            """
        )

        let request = try await connection.requests.first()
        XCTAssertEqual(
            request,
            .make(method: .GET, version: .http11, path: "/hello/world")
        )

        try await s1.close()
        try await s2.close()
    }
}
