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
#if canImport(CryptoKit)
import CryptoKit
#endif

public struct DirectoryHTTPHandler: HTTPHandler {

    private(set) var root: URL?
    let serverPath: String
    let cacheControl: [CacheControl.ResponseDirective]

    public init(root: URL, serverPath: String = "/") {
        self.root = root
        self.serverPath = serverPath
        self.cacheControl = [.private]
    }

    public init(bundle: Bundle,
                subPath: String = "",
                serverPath: String,
                cacheControl: [CacheControl.ResponseDirective] = [.private]) {
        self.root = bundle.resourceURL?.appendingPathComponent(subPath)
        self.serverPath = serverPath
        self.cacheControl = cacheControl
    }

    public func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard
            let filePath = makeFileURL(for: request.path),
            let data = try? Data(contentsOf: filePath) else {
            return HTTPResponse(statusCode: .notFound)
        }
        
        var headers: HTTPHeaders = [
            .contentType: FileHTTPHandler.makeContentType(for: filePath.absoluteString),
            .cacheControl: cacheControl.serialized(),
            .date: Self.dateFormatter.string(from: Date())
        ]
        
        if let expiresValue = generateExpiresValue(for: filePath) {
            headers[.lastModified] = expiresValue
            
            if let ifModifiedSince = request.headers[.ifModifiedSince], expiresValue == ifModifiedSince {
                return HTTPResponse(statusCode: .notModified,
                                    headers: headers)
            }
        }
        
#if canImport(CryptoKit)
        let eTag = generateETag(for: data)
        headers[.eTag] = eTag
        
        if let ifNoneMatch = request.headers[.ifNoneMatch], eTag == ifNoneMatch {
            return HTTPResponse(statusCode: .notModified,
                                headers: headers)
        }
#endif

        return HTTPResponse(
            statusCode: .ok,
            headers: headers,
            body: data
        )
    }

    func makeFileURL(for requestPath: String) -> URL? {
        let compsA = serverPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .joined(separator: "/")

        let compsB = requestPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .joined(separator: "/")

        guard compsB.hasPrefix(compsA) else { return nil }
        let subPath = String(compsB.dropFirst(compsA.count))
        return root?.appendingPathComponent(subPath)
    }
    
    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE, d MMM yyyy HH:mm:ss zzz"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
    
    private func generateExpiresValue(for filePath: URL) -> String? {
        do {
            let path = {
                if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                    return filePath.path()
                } else {
                    return filePath.path
                }
            }()
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            if let modificationDate = attributes[FileAttributeKey.modificationDate] as? Date ?? attributes[FileAttributeKey.creationDate] as? Date {
                return Self.dateFormatter.string(from: modificationDate)
            }
        } catch {
        }
        return nil
    }
    
#if canImport(CryptoKit)
    private func generateETag(for data: Data) -> String {
        let sha256digest = SHA256.hash(data: data)
        let eTag = "\"\(sha256digest.map { String(format: "%02x", $0) }.joined())\""
        return eTag
    }
#endif
}
