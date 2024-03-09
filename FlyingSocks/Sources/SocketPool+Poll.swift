//
//  SocketPool+Poll.swift
//  FlyingFox
//
//  Created by Simon Whitty on 24/09/2022.
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

public extension AsyncSocketPool where Self == SocketPool<Poll> {
    static func poll(interval: Poll.Interval = .seconds(0.01), logger: some Logging = .disabled) -> SocketPool<Poll> {
        .init(interval: interval, logger: logger)
    }

    private init(interval: Poll.Interval = .seconds(0.01), logger: some Logging) {
        self.init(queue:  Poll(interval: interval, logger: logger), logger: logger)
    }
}

public struct Poll: EventQueue {

    private(set) var entries: Set<Entry>
    private var isOpen: Bool = false
    private let interval: Interval
    private let logger: any Logging

    struct Entry: Hashable {
        var file: Socket.FileDescriptor
        var events: Socket.Events
    }

    public enum Interval: Sendable {
        case immediate
        case seconds(TimeInterval)
    }

    public init(interval: Interval, logger: some Logging = .disabled) {
        self.entries = []
        self.interval = interval
        self.logger = logger
    }

    public mutating func open() {
        entries = []
        isOpen = true
    }

    public mutating func close() {
        entries = []
        isOpen = false
    }

    public mutating func addEvents(_ events: Socket.Events, for socket: Socket.FileDescriptor) throws {
        guard isOpen else { throw SocketError.makeFailed("poll.addEvents notReady") }
        let entry = Entry(file: socket, events: events)
        entries.insert(entry)
    }

    public mutating func removeEvents(_ events: Socket.Events, for socket: Socket.FileDescriptor) throws {
        guard isOpen else { throw SocketError.makeFailed("poll.removeEvents notReady") }
        let entry = Entry(file: socket, events: events)
        entries.remove(entry)
    }

    public func getNotifications() throws -> [EventNotification] {
        guard isOpen else { throw SocketError.makeFailed("poll.getNotifications notReady") }
        var buffer = entries.map(\.pollfd)

        let status = Socket.poll(&buffer, UInt32(buffer.count), interval.milliseconds)
        guard status > -1 else {
            throw SocketError.makeFailed("poll.getNotifications poll")
        }

        return buffer.compactMap(EventNotification.make)
    }
}

extension Poll.Entry {
    var pollfd: pollfd {
        Socket.pollfd(fd: file.rawValue,
                      events: Int16(events.pollEvents.rawValue),
                      revents: 0)
    }
}

extension EventNotification {

    static func make(from poll: pollfd) -> Self? {
        let events = POLLEvents(poll.events)
        let revents = POLLEvents(poll.revents)
        let errors = Set<EventNotification.Error>.make(from: revents)

        if events.contains(.write) && !errors.isEmpty {
            return EventNotification(
                file: .init(rawValue: poll.fd),
                events: .init(events),
                errors: errors
            )
        }

        guard events.intersects(with: revents) else {
            return nil
        }

        let notification = EventNotification(
            file: .init(rawValue: poll.fd),
            events: .init(revents),
            errors: []
        )

        return notification
    }
}

extension Poll.Interval {
    var milliseconds: Int32 {
        switch self {
        case .immediate:
            return 0
        case .seconds(let seconds):
            return Int32(seconds * 1000)
        }
    }
}

private struct POLLEvents: OptionSet, Hashable {
    var rawValue: Int32

    static let read = POLLEvents(rawValue: POLLIN)
    static let write = POLLEvents(rawValue: POLLOUT)
    static let err = POLLEvents(rawValue: POLLERR)
    static let hup = POLLEvents(rawValue: POLLHUP)
    static let nval = POLLEvents(rawValue: POLLNVAL)

    static let errors: POLLEvents = [.err, .hup, .nval]

    func intersects(with events: POLLEvents) -> Bool {
        !intersection(events).isEmpty
    }

    init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    init(_ events: Int16) {
        self.rawValue = Int32(events)
    }
}

private extension Socket.Event {
    var pollEvents: POLLEvents {
        switch self {
        case .read:
            return .read
        case .write:
            return .write
        }
    }
}

private extension Socket.Events {
    var pollEvents: POLLEvents {
        reduce(POLLEvents()) { [$0, $1.pollEvents] }
    }

    init(_ events: POLLEvents) {
        self = []
        if events.contains(.read) {
            self.insert(.read)
        }
        if events.contains(.write) {
            self.insert(.write)
        }
    }
}

private extension Set where Element == EventNotification.Error {

    static func make(from revents: POLLEvents) -> Self {
        var errors = Set<EventNotification.Error>()
        if revents.contains(.hup) {
            errors.insert(.endOfFile)
        }
        if revents.contains(.nval) || revents.contains(.err) {
            errors.insert(.error)
        }
        return errors
    }
}
