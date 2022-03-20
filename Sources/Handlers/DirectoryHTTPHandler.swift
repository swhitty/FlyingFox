//
//  DirectoryHTTPHandler.swift
//  FlyingFox
//
//  Created by Huw Rowlands on 20/03/2022.
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

public struct DirectoryHTTPHandler: HTTPHandler {

    @UncheckedSendable
    private(set) var root: URL?
    let serverPath: String

    public init(root: URL, serverPath: String) {
        self.root = root
        self.serverPath = serverPath
    }

    public init(bundle: Bundle, subPath: String? = nil, serverPath: String) {
        self.root = bundle.resourceURL?.appendingPathComponent(subPath ?? "")
        self.serverPath = serverPath
    }

    public func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard request.path.hasPrefix(serverPath) else {
            return HTTPResponse(statusCode: .notFound)
        }

        let subPath = String(request.path.dropFirst(serverPath.count))

        guard
            let filePath = root?.appendingPathComponent(subPath),
            let data = try? Data(contentsOf: filePath)
        else {
            return HTTPResponse(statusCode: .notFound)
        }

        return HTTPResponse(
            statusCode: .ok,
            headers: [.contentType: FileHTTPHandler.makeContentType(for: filePath.absoluteString)],
            body: data
        )
    }

}
