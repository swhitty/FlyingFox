//
//  FileHTTPHandler.swift
//  FlyingFox
//
//  Created by Simon Whitty on 14/02/2022.
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

public struct FileHTTPHandler: HTTPHandler {

    @UncheckedSendable
    private(set) var path: URL?
    let contentType: String

    public init(path: URL, contentType: String) {
        self.path = path
        self.contentType = contentType
    }

    public init(named: String, in bundle: Bundle, contentType: String? = nil) {
        self.path = bundle.url(forResource: named, withExtension: nil)
        self.contentType = contentType ?? Self.makeContentType(for: named)
    }

    static func makeContentType(for filename: String) -> String {
        // TODO: UTTypeCreatePreferredIdentifierForTag / UTTypeCopyPreferredTagWithClass
        let pathExtension = (filename.lowercased() as NSString).pathExtension
        switch pathExtension {
        case "json":
            return "application/json"
        case "html", "htm":
            return "text/html"
        case "css":
            return "text/css"
        case "js", "javascript":
            return "application/javascript"
        case "png":
            return "image/png"
        case "jpeg", "jpg":
            return "image/jpeg"
        case "pdf":
            return "application/pdf"
        default:
            return "application/octet-stream"
        }
    }

    public func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let path = path,
              let data = try? Data(contentsOf: path) else {
                  return HTTPResponse(statusCode: .notFound)
              }

        return HTTPResponse(statusCode: .ok,
                            headers: [.contentType: contentType],
                            body: data)
    }
}
