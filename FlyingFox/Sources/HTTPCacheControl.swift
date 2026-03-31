//
//  HTTPCacheControl.swift
//  FlyingFox
//
//  Created by Spassov, Nikolay on 31.03.26.
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

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

    static func getDateHeaderValue() -> String {
        return Self.dateFormatter.string(from: Date())
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE, d MMM yyyy HH:mm:ss zzz"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

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
                return Self.dateFormatter.string(from: modificationDate)
            }
        } catch {
        }
        return nil
    }

    static func getETagValue(for data: Data) -> String? {
#if canImport(CryptoKit)
        let sha256digest = SHA256.hash(data: data)
        let eTag = "\"\(sha256digest.map { String(format: "%02x", $0) }.joined())\""
        return eTag
#else
        return nil
#endif
    }
}

extension [HTTPCacheControl.ResponseDirective] {
    func getSerializedValue() -> String {
        let directives: [HTTPCacheControl.ResponseDirective] = self.isEmpty ? [.private] : self
        return Set(directives.map({ $0.description })).joined(separator: ",")
    }
}
