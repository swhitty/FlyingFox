//
//  HTTPDecoder+StandardizePath.swift
//  FlyingFox
//
//  Created by Simon Whitty on 23/08/2025.
//  Copyright © 2025 Simon Whitty. All rights reserved.
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

extension HTTPDecoder {

    static func standardizePath(_ path: String) -> String? {
        standardizePath(path, fallback: false)
    }

    static func standardizePath(_ path: String, fallback: Bool) -> String? {
        #if canImport(Darwin)
            #if compiler(>=6.2)
            if !fallback, #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
                return URL(string: path)?.standardized.path
            } else {
                return standardizePathDarwinFallback(path)
            }
            #else
            return standardizePathDarwinFallback(path)
            #endif
        #else
        return URL(string: path)?.standardized.path
        #endif
    }

    private static func standardizePathDarwinFallback(_ path: String) -> String? {
        if #available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, visionOS 26.0, *) {
            return URL(string: path.removingDotSegments)?.standardized.path
        } else {
            return URL(string: path)?.standardized.path
        }
    }
}

// Fix taken from
// https://github.com/swiftlang/swift-foundation/blob/main/Sources/FoundationEssentials/URL/URL_Swift.swift

//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

private extension String {
    @available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, visionOS 26.0, *)
    var removingDotSegments: String {
        guard !isEmpty else {
            return ""
        }

        enum RemovingDotState {
            case initial
            case dot
            case dotDot
            case slash
            case slashDot
            case slashDotDot
            case appendUntilSlash
        }

        return String(unsafeUninitializedCapacity: utf8.count) { buffer in

            // State machine for remove_dot_segments() from RFC 3986
            //
            // First, remove all "./" and "../" prefixes by moving through
            // the .initial, .dot, and .dotDot states (without appending).
            //
            // Then, move through the remaining states/components, first
            // checking if the component is special ("/./" or "/../") so
            // that we only append when necessary.

            var state = RemovingDotState.initial
            var i = 0
            for v in utf8 {
                switch state {
                case .initial:
                    if v == ._dot {
                        state = .dot
                    } else if v == ._slash {
                        state = .slash
                    } else {
                        buffer[i] = v
                        i += 1
                        state = .appendUntilSlash
                    }
                case .dot:
                    if v == ._dot {
                        state = .dotDot
                    } else if v == ._slash {
                        state = .initial
                    } else {
                        i = buffer[i...i+1].initialize(fromContentsOf: [._dot, v])
                        state = .appendUntilSlash
                    }
                case .dotDot:
                    if v == ._slash {
                        state = .initial
                    } else {
                        i = buffer[i...i+2].initialize(fromContentsOf: [._dot, ._dot, v])
                        state = .appendUntilSlash
                    }
                case .slash:
                    if v == ._dot {
                        state = .slashDot
                    } else if v == ._slash {
                        buffer[i] = ._slash
                        i += 1
                    } else {
                        i = buffer[i...i+1].initialize(fromContentsOf: [._slash, v])
                        state = .appendUntilSlash
                    }
                case .slashDot:
                    if v == ._dot {
                        state = .slashDotDot
                    } else if v == ._slash {
                        state = .slash
                    } else {
                        i = buffer[i...i+2].initialize(fromContentsOf: [._slash, ._dot, v])
                        state = .appendUntilSlash
                    }
                case .slashDotDot:
                    if v == ._slash {
                        // Cheaply remove the previous component by moving i to its start
                        i = buffer[..<i].lastIndex(of: ._slash) ?? 0
                        state = .slash
                    } else {
                        i = buffer[i...i+3].initialize(fromContentsOf: [._slash, ._dot, ._dot, v])
                        state = .appendUntilSlash
                    }
                case .appendUntilSlash:
                    if v == ._slash {
                        state = .slash
                    } else {
                        buffer[i] = v
                        i += 1
                    }
                }
            }

            switch state {
            case .slash: fallthrough
            case .slashDot:
                buffer[i] = ._slash
                i += 1
            case .slashDotDot:
                // Note: "/.." is not yet appended to the buffer
                i = buffer[..<i].lastIndex(of: ._slash) ?? 0
                buffer[i] = ._slash
                i += 1
            default:
                break
            }

            return i
        }
    }
}

private extension UInt8 {
    static var _slash: UInt8 { UInt8(ascii: "/") }
    static var _dot: UInt8 { UInt8(ascii: ".") }
}
