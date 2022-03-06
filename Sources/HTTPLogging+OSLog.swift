//
//  HTTPLogging+OSLog.swift
//  FlyingFox
//
//  Created by Simon Whitty on 19/02/2022.
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

#if canImport(OSLog)
import OSLog

@available(macOS 11.0, iOS 14.0, tvOS 14.0, *)
public struct OSLogHTTPLogging: HTTPLogging {

    private let logger: Logger

    public init(logger: Logger) {
        self.logger = logger
    }

    public func logDebug(_ debug: String) {
        logger.debug("\(debug, privacy: .public)")
    }
        
    public func logInfo(_ info: String) {
        logger.info("\(info, privacy: .public)")
    }

    public func logWarning(_ warning: String) {
        logger.warning("\(warning, privacy: .public)")
    }

    public func logError(_ error: String) {
        logger.error("\(error, privacy: .public)")
    }
    
    public func logCritical(_ critical: String) {
        logger.critical("\(critical, privacy: .public)")
    }

}

@available(macOS 11.0, iOS 14.0, tvOS 14.0, *)
public extension HTTPLogging where Self == OSLogHTTPLogging {

    static func oslog(bundle: Bundle = .main, category: String = "FlyingFox") -> Self {
        let logger = Logger(subsystem: bundle.bundleIdentifier ?? category,
                            category: category)
        return OSLogHTTPLogging(logger: logger)
    }
}

#endif
