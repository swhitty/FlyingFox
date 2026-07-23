//
//  HTTPCacheControl.swift
//  FlyingFox
//
//  Created by Spassov, Nikolay on 31.03.26.
//

import Foundation

public enum HTTPCacheControl {
    public enum ResponseDirective: Sendable, CustomStringConvertible {
        case maxAge(Int)
        case sharedMaxAge(Int)
        case noCache
        case noStore
        case noTransform
        case mustRevalidate
        case proxyRevalidate
        case mustUnderstand
        case `private`
        case `public`
        case immutable
        case staleWhileRevalidate
        case staleIfError

        public var description: String {
            switch self {
            case .maxAge(let value):
                return "max-age=\(value)"
            case .sharedMaxAge(let value):
                return "s-maxage=\(value)"
            case .noCache:
                return "no-cache"
            case .noStore:
                return "no-store"
            case .noTransform:
                return "no-transform"
            case .mustRevalidate:
                return "must-revalidate"
            case .proxyRevalidate:
                return "proxy-revalidate"
            case .mustUnderstand:
                return "must-understand"
            case .private:
                return "private"
            case .public:
                return "public"
            case .immutable:
                return "immutable"
            case .staleWhileRevalidate:
                return "stale-while-revalidate"
            case .staleIfError:
                return "stale-if-error"
            }
        }
    }

    static func getExpiresValue(for filePath: URL) -> String? {
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
                return HTTPDate.string(from: modificationDate)
            }
        } catch {
        }
        return nil
    }

    // Strong ETag derived from (mtime, size), matching the format used by
    // nginx (`"%xT-%xO"`, see ngx_http_set_etag in src/http/ngx_http_core_module.c)
    // and Apache HTTPD's default `FileETag MTime Size`. Cheap to compute and
    // does not require reading file contents.
    static func getETagValue(for filePath: URL) -> String? {
        let path = {
            if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                return filePath.path()
            } else {
                return filePath.path
            }
        }()
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let modificationDate = attributes[.modificationDate] as? Date,
              let size = attributes[.size] as? UInt64 else {
            return nil
        }
        let mtime = Int64(modificationDate.timeIntervalSince1970)
        return String(format: "\"%llx-%llx\"", mtime, size)
    }
}

extension [HTTPCacheControl.ResponseDirective] {
    func getSerializedValue() -> String {
        let directives: [HTTPCacheControl.ResponseDirective] = self.isEmpty ? [.private] : self
        return Set(directives.map({ $0.description })).joined(separator: ",")
    }
}
