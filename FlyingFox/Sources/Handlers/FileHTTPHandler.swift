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

import FlyingSocks
import Foundation
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

public struct FileHTTPHandler: HTTPHandler {

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
        let pathExtension = (filename.lowercased() as NSString).pathExtension
#if canImport(UniformTypeIdentifiers)
        if #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *) {
            switch pathExtension {
            case "wasm":
                return "application/wasm"
            case "js", "javascript":
                return "application/javascript"
            case "properties":
                return "text/plain"
            default:
                return UTType(filenameExtension: pathExtension)?.preferredMIMEType ?? legacyMakeContentType(for: pathExtension)
            }
        } else {
            return legacyMakeContentType(for: pathExtension)
        }
#else
        return legacyMakeContentType(for: pathExtension)
#endif
    }
    
    private static func legacyMakeContentType(for pathExtension: String) -> String {
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
        case "mp4":
            return "video/mp4"
        case "m4v":
            return "video/x-m4v"
        case "pdf":
            return "application/pdf"
        case "svg":
            return "image/svg+xml"
        case "txt":
            return "text/plain"
        case "ico":
            return "image/vnd.microsoft.icon"
        case "wasm":
            return "application/wasm"
        case "webp":
            return "image/webp"
        case "jp2":
            return "image/jp2"
        case "properties":
            return "text/plain"
        case "xml":
            return "application/xml"
        default:
            return "application/octet-stream"
        }
    }

    public func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let path = path else {
            return HTTPResponse(statusCode: .notFound)
        }

        do {
            var headers: HTTPHeaders = [
                .contentType: contentType,
                .acceptRanges: "bytes"
            ]

            let fileSize = try AsyncBufferedFileSequence.fileSize(at: path)

            if request.method == .HEAD {
                headers[.contentLength] = String(fileSize)
                return HTTPResponse(
                    statusCode: .ok,
                    headers: headers
                )
            }

            if let range = Self.makePartialRange(for: request.headers, fileSize: fileSize) {
                headers[.contentRange] = "bytes \(range.lowerBound)-\(range.upperBound)/\(fileSize)"
                return try HTTPResponse(
                    statusCode: .partialContent,
                    headers: headers,
                    body: HTTPBodySequence(file: path, range: range.lowerBound..<range.upperBound + 1)
                )
            } else {
                return try HTTPResponse(
                    statusCode: .ok,
                    headers: headers,
                    body: HTTPBodySequence(file: path)
                )
            }
        } catch {
            return HTTPResponse(statusCode: .notFound)
        }
    }

    static func makePartialRange(for headers: HTTPHeaders, fileSize: Int) -> ClosedRange<Int>? {
        guard let headerValue = headers[.range] else { return nil }
        let scanner = Scanner(string: headerValue)
        guard scanner.scanString("bytes") != nil,
              scanner.scanString("=") != nil,
              let start = scanner.scanInt(),
              scanner.scanString("-") != nil else {
            return nil
        }

        // if no end clamp at 10MB
        let end = scanner.scanInt() ?? min(start + 10_000_000, fileSize) - 1
        guard start <= end else { return nil }
        return start...end
    }
}
