//
//  FormDataSequenceTests.swift
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

@testable import FlyingFox
import FlyingSocks
@_spi(Private) import struct FlyingSocks.AsyncDataSequence
import XCTest

final class FormDataSequenceTests: XCTestCase {

    func testRequestWithFormdataSequence() async throws {
        // todo: needs to include \r
        let request = HTTPRequest.make(
            headers: [.contentType: "multipart/form-data; boundary=**ZZ"],
            body: #"""
            --**ZZ\#r
            Content-Disposition: form-data; name="text1"\#r
            Content-Type: text/plain\#r
            \#r
            Fish & Chips\#r
            --**ZZ\#r
            Content-Disposition: form-data; name="text2"\#r
            \#r
            Shrimp
            Scampi\#r
            --**ZZ\#r
            Content-Disposition: form-data; name="text3"\#r
            \#r
            \#r
            --**ZZ--
            """#
        )

        let parts = try await request.formDataSequence.collectAll()

        XCTAssertEqual(
            parts,
            [
                .make(
                    headers: [
                        .contentDisposition: #"form-data; name="text1""#,
                        .contentType: "text/plain"
                    ],
                    body: "Fish & Chips"
                ),
                .make(
                    headers: [
                        .contentDisposition: #"form-data; name="text2""#,
                    ],
                    body: "Shrimp\nScampi"
                ),
                .make(
                    headers: [
                        .contentDisposition: #"form-data; name="text3""#,
                    ],
                    body: ""
                )
            ]
        )

        XCTAssertEqual(
            parts.map(\.name),
            ["text1", "text2", "text3"]

        )
    }
}

private extension FormDataSequence where S == AsyncDataSequence {

    static func make(body: String, chunkSize: Int = 5, boundary: String) async throws -> Self {
        let data = body.data(using: .utf8)!
        let asyncData = AsyncDataSequence(
            from: ConsumingAsyncSequence(data),
            count: data.count,
            chunkSize: chunkSize
        )
        return try await FormDataSequence.make(
            body: asyncData,
            boundary: boundary
        )
    }
}

private extension FormData {

    static func make(
        headers: [FormHeader: String] = [:],
        body: String = ""
    ) -> Self {
        FormData(
            headers: headers,
            body: body.data(using: .utf8)!
        )
    }
}
