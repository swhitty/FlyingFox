//
//  SocketPool+kQueue.swift
//  FlyingFox
//
//  Created by Simon Whitty on 10/09/2022.
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

#if canImport(Darwin)
import Darwin

public extension AsyncSocketPool where Self == SocketPool<kQueue> {
    static func kQueue(maxEvents limit: Int = 20, logger: some Logging = .disabled) -> SocketPool<kQueue> {
        .init(maxEvents: limit, logger: logger)
    }

    private init(maxEvents limit: Int, logger: some Logging = .disabled) {
        self.init(queue: FlyingSocks.kQueue(maxEvents: limit, logger: logger), logger: logger)
    }
}

public struct kQueue: EventQueue {

    private(set) var file: Socket.FileDescriptor
    private(set) var existing: [Socket.FileDescriptor: Socket.Events]
    private(set) var isStopped: Bool
    private let eventsLimit: Int
    private let logger: any Logging

    /// Identifier of the EVFILT_USER event that `stop()` triggers to wake `getNotifications()`.
    static let wakeIdent: UInt = 0

    public init(maxEvents limit: Int, logger: some Logging = .disabled) {
        self.file = .invalid
        self.existing = [:]
        self.isStopped = false
        self.eventsLimit = limit
        self.logger = logger
    }

    public mutating func open() throws {
        existing = [:]
        isStopped = false
        let file = try Self.makeQueue()
        do {
            try Self.addWakeEvent(to: file)
        } catch {
            try? Self.closeQueue(file: file)
            throw error
        }
        self.file = file
    }

    /// Wakes any `getNotifications()` waiting on the queue without closing it.
    ///
    /// The wake event is left triggered, so every later wait returns at once. Closing the
    /// queue here instead would race a wait that is about to start: its descriptor could be
    /// reused by another queue before `kevent` is called, which would then wait on, and take
    /// events from, a queue it does not own.
    public mutating func stop() throws {
        existing = [:]
        guard file != .invalid, !isStopped else {
            throw SocketError.disconnected
        }
        isStopped = true
        try Self.triggerWakeEvent(on: file)
    }

    /// Closes the queue. Call only once no `getNotifications()` can still be waiting on it.
    public mutating func close() throws {
        guard file != .invalid else { return }
        defer { file = .invalid }
        try Self.closeQueue(file: file)
    }

    public mutating func addEvents(_ events: Socket.Events, for socket: Socket.FileDescriptor) throws {
        for event in events {
            // Add the event even when it is recorded as added: EV_ADD of a filter the kqueue
            // has just updates it, but a descriptor closed while registered has left the
            // kqueue, and skipping the add would leave a socket since given the descriptor
            // never woken.
            try addEvent(event, for: socket)
            var socketEvents = existing[socket] ?? []
            socketEvents.insert(event)
            existing[socket] = socketEvents
        }
    }

    func addEvent(_ event: Socket.Event, for socket: Socket.FileDescriptor) throws {
        var event = Darwin.kevent(
            ident: UInt(socket.rawValue),
            filter: event.kqueueFilter,
            flags: UInt16(EV_ADD | EV_ENABLE),
            fflags: 0,
            data: 0,
            udata: nil
        )
        guard kevent(file.rawValue, &event, 1, nil, 0, nil) != -1 else {
            throw SocketError.makeFailed("kqueue add kevent")
        }
    }

    public mutating func removeEvents(_ events: Socket.Events, for socket: Socket.FileDescriptor) throws {
        for event in events {
            guard var entries = existing[socket], entries.contains(event) else { continue }
            // Forget the event before removing it: a socket closed while registered has left
            // the kqueue already, so the removal fails, and remembering the event would stop
            // it being added for a socket later given the same descriptor.
            entries.remove(event)
            existing[socket] = entries.isEmpty ? nil : entries
            try removeEvent(event, for: socket)
        }
    }

    func removeEvent(_ event: Socket.Event, for socket: Socket.FileDescriptor) throws {
        var event = Darwin.kevent(
            ident: UInt(socket.rawValue),
            filter: event.kqueueFilter,
            flags: UInt16(EV_DELETE | EV_DISABLE),
            fflags: 0,
            data: 0,
            udata: nil
        )
        guard kevent(file.rawValue, &event, 1, nil, 0, nil) != -1 else {
            throw SocketError.makeFailed("kqueue remove kevent")
        }
    }

    public func getNotifications() throws -> [EventNotification] {
        guard file != .invalid, !isStopped else {
            throw SocketError.disconnected
        }
        var events = Array(repeating: kevent(), count: eventsLimit)
        let status = kevent(file.rawValue, nil, 0, &events, Int32(eventsLimit), nil)
        guard status > 0 else {
            // EINTR (signal) is not a failure: report no events so the caller
            // polls again rather than tearing down the server. See kevent(2).
            if status == -1 && errno == EINTR {
                return []
            }
            throw SocketError.makeFailed("kqueue kevent")
        }

        let received = events.prefix(Int(status))
        if received.contains(where: \.isWakeEvent) {
            throw SocketError.disconnected
        }
        return received.compactMap(EventNotification.make)
    }

    static func makeQueue(file: Int32 = Darwin.kqueue()) throws -> Socket.FileDescriptor {
        let file = Socket.FileDescriptor(rawValue: file)
        guard file != .invalid else {
            throw SocketError.makeFailed("kqueue")
        }
        return file
    }

    static func addWakeEvent(to file: Socket.FileDescriptor) throws {
        // Without EV_CLEAR the event stays triggered once `stop()` triggers it.
        var event = Darwin.kevent(
            ident: wakeIdent,
            filter: Int16(EVFILT_USER),
            flags: UInt16(EV_ADD | EV_ENABLE),
            fflags: 0,
            data: 0,
            udata: nil
        )
        guard kevent(file.rawValue, &event, 1, nil, 0, nil) != -1 else {
            throw SocketError.makeFailed("kqueue add wake kevent")
        }
    }

    static func triggerWakeEvent(on file: Socket.FileDescriptor) throws {
        var event = Darwin.kevent(
            ident: wakeIdent,
            filter: Int16(EVFILT_USER),
            flags: 0,
            fflags: UInt32(NOTE_TRIGGER),
            data: 0,
            udata: nil
        )
        guard kevent(file.rawValue, &event, 1, nil, 0, nil) != -1 else {
            throw SocketError.makeFailed("kqueue trigger wake kevent")
        }
    }

    static func closeQueue(file: Socket.FileDescriptor) throws {
        guard file != .invalid else { return }
        guard Socket.close(file.rawValue) >= 0 else {
            throw SocketError.makeFailed("kqueue")
        }
    }
}

extension kevent {
    var isWakeEvent: Bool {
        filter == Int16(EVFILT_USER) && ident == kQueue.wakeIdent
    }
}

extension EventNotification {

    static func make(from event: kevent) -> Self? {
        guard let filter = Socket.Event.make(from: event.filter) else {
            return nil
        }
        var notification = EventNotification(
            file: .init(rawValue: Int32(event.ident)),
            events: [filter],
            errors: []
        )

        if filter == .read && event.data > 0 {
            // ignore read errors until there is no data available
            return notification
        }

        if (event.flags & UInt16(EV_EOF)) == EV_EOF {
            notification.errors.insert(.endOfFile)
        }
        if (event.flags & UInt16(EV_ERROR)) == EV_ERROR {
            notification.errors.insert(.error)
        }

        return notification
    }
}

extension Socket.Event {
    var kqueueFilter: Int16 {
        switch self {
        case .read: return Int16(EVFILT_READ)
        case .write: return Int16(EVFILT_WRITE)
        }
    }

    static func make(from filter: Int16) -> Self? {
        switch Int32(filter) {
        case EVFILT_READ: return .read
        case EVFILT_WRITE: return .write
        default: return nil
        }
    }
}
#endif
