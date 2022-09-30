//
//  Logging.swift
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

public protocol Logging: Sendable {
    func logDebug(_ debug: String)
    func logInfo(_ info: String)
    func logWarning(_ warning: String)
    func logError(_ error: String)
    func logCritical(_ critical: String)
}

public struct PrintLogger: Logging {

    let category: String

    public init(category: String) {
        self.category = category
    }

    public func logDebug(_ debug: String) {
        Swift.print("[\(category)] debug: \(debug)")
    }
    
    public func logInfo(_ info: String) {
        Swift.print("[\(category)] info: \(info)")
    }

    public func logWarning(_ warning: String) {
        Swift.print("[\(category)] warning: \(warning)")
    }
    
    public func logError(_ error: String) {
        Swift.print("[\(category)] error: \(error)")
    }
    
    public func logCritical(_ critical: String) {
        Swift.print("[\(category)] critical: \(critical)")
    }
}

public extension Logging where Self == PrintLogger {

    static func print(category: String) -> Self {
        return PrintLogger(category: category)
    }
}
