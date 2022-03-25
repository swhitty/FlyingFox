//
//  HTTPHandler.swift
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

public protocol HTTPHandler: Sendable {
    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse
}

public struct HTTPUnhandledError: LocalizedError {
    public let errorDescription: String? = "HTTPHandler can not handle the request."
    public init() { }
}

public extension HTTPHandler where Self == FileHTTPHandler {
    static func file(named: String, in bundle: Bundle = .main) -> FileHTTPHandler {
        FileHTTPHandler(named: named, in: bundle)
    }
}

public extension HTTPHandler where Self == DirectoryHTTPHandler {
    static func directory(for bundle: Bundle = .main, subPath: String = "", serverPath: String = "") -> DirectoryHTTPHandler {
        DirectoryHTTPHandler(bundle: bundle, subPath: subPath, serverPath: serverPath)
    }
}

public extension HTTPHandler where Self == RedirectHTTPHandler {
    static func redirect(to location: String) -> RedirectHTTPHandler {
        RedirectHTTPHandler(location: location)
    }
}

public extension HTTPHandler where Self == ProxyHTTPHandler {
    static func proxy(via url: String) -> ProxyHTTPHandler {
        ProxyHTTPHandler(base: url)
    }
}

public extension HTTPHandler where Self == ClosureHTTPHandler {
    static func unhandled() -> ClosureHTTPHandler {
        ClosureHTTPHandler { _ in throw HTTPUnhandledError() }
    }
}

public extension HTTPHandler where Self == WebSocketHTTPHander {
    static func webSocket(_ handler: WSMessageHandler, frameSize: Int = 16384) -> WebSocketHTTPHander {
        WebSocketHTTPHander(handler: MessageFrameWSHandler(handler: handler, frameSize: frameSize))
    }
}
