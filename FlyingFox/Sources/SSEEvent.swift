//
//  SSEEvent.swift
//  FlyingFox
//
//  Created by Simon Whitty on 16/11/2026.
//  Copyright © 2026 Simon Whitty. All rights reserved.
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

/// An event sent to the client in a `text/event-stream` response.
///
/// Fields are encoded as described in the WHATWG HTML Living Standard, "Server-sent events" §9.2.6.
public struct SSEEvent: Sendable, Hashable {

    /// The `event` field. Clients dispatch the event with this type, or `message` when nil.
    public let event: String?

    /// The `data` field. Multi-line data is sent as one `data` line per line. An event without
    /// data is not dispatched by the client, but still updates its last event ID and retry time.
    public let data: String?

    /// The `id` field. Clients send the last ID they received in `Last-Event-ID` when they reconnect.
    public let id: String?

    /// The `retry` field: the time in milliseconds the client waits before reconnecting.
    public let retry: Int?

    /// A comment, which clients ignore. An empty comment keeps an idle connection open.
    public let comment: String?

    /// An event with only data, dispatched to the client as a `message` event.
    public init(data: String) {
        self.event = nil
        self.data = data
        self.id = nil
        self.retry = nil
        self.comment = nil
    }

    /// An event with any combination of fields.
    /// - Throws: `SSEEvent.InvalidField` when `event` or `id` contain a line break, `id` contains
    ///   NULL, or `retry` is negative.
    public init(event: String? = nil, data: String? = nil, id: String? = nil, retry: Int? = nil) throws {
        // §9.2.6 lines end at CR, LF or CRLF, so a line break would end the field early.
        if let event, event.containsLineBreak {
            throw InvalidField.event
        }
        // §9.2.6 a client ignores an id field that contains NULL.
        if let id, id.containsLineBreak || id.unicodeScalars.contains("\0") {
            throw InvalidField.id
        }
        // §9.2.6 a retry field must consist of only ASCII digits.
        if let retry, retry < 0 {
            throw InvalidField.retry
        }
        self.event = event
        self.data = data
        self.id = id
        self.retry = retry
        self.comment = nil
    }

    private init(comment: String) {
        self.event = nil
        self.data = nil
        self.id = nil
        self.retry = nil
        self.comment = comment
    }

    /// A comment line, ignored by clients. Multi-line comments are sent as one line each.
    public static func comment(_ text: String = "") -> SSEEvent {
        SSEEvent(comment: text)
    }

    public enum InvalidField: Error, Hashable {
        case event
        case id
        case retry
    }
}

extension SSEEvent {

    /// The UTF-8 encoded event, ending with a blank line (§9.2.5).
    var encoded: [UInt8] {
        var text = ""
        if let comment {
            for line in comment.splitLines() {
                text += line.isEmpty ? ":\n" : ": \(line)\n"
            }
        }
        // A single space after the colon is removed by the client (§9.2.6), so writing it
        // keeps a value that itself starts with a space.
        if let event {
            text += "event: \(event)\n"
        }
        if let id {
            text += "id: \(id)\n"
        }
        if let retry {
            text += "retry: \(retry)\n"
        }
        if let data {
            for line in data.splitLines() {
                text += "data: \(line)\n"
            }
        }
        text += "\n"
        return Array(text.utf8)
    }
}

private extension String {

    var containsLineBreak: Bool {
        unicodeScalars.contains { $0 == "\r" || $0 == "\n" }
    }

    /// Splits at CRLF, CR or LF only (§9.2.5), keeping empty lines. Other Unicode line
    /// separators are not line breaks in an event stream.
    func splitLines() -> [Substring] {
        split(omittingEmptySubsequences: false) { $0 == "\r\n" || $0 == "\r" || $0 == "\n" }
    }
}
