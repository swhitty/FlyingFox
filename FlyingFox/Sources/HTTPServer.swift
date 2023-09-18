//
//  HTTPServer.swift
//  FlyingFox
//
//  Created by Simon Whitty on 13/02/2022.
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
@_spi(Private) import func FlyingSocks.withThrowingTimeout
import Foundation
#if canImport(WinSDK)
import WinSDK.WinSock2
#endif

public final actor HTTPServer {

    let pool: AsyncSocketPool
    private let address: sockaddr_storage
    private let timeout: TimeInterval
    private let logger: Logging?
    private var handlers: RoutedHTTPHandler

    public init<A: SocketAddress>(address: A,
                                  timeout: TimeInterval = 15,
                                  pool: AsyncSocketPool = defaultPool(),
                                  logger: Logging? = defaultLogger(),
                                  handler: HTTPHandler? = nil) {
        self.address = address.makeStorage()
        self.timeout = timeout
        self.pool = pool
        self.logger = logger
        self.handlers = Self.makeRootHandler(to: handler)
    }

    public var listeningAddress: Socket.Address? {
        try? state?.socket.sockname()
    }

    public func appendRoute(_ route: HTTPRoute, to handler: HTTPHandler) {
        handlers.appendRoute(route, to: handler)
    }

    public func appendRoute(_ route: HTTPRoute, handler: @Sendable @escaping (HTTPRequest) async throws -> HTTPResponse) {
        handlers.appendRoute(route, handler: handler)
    }

    public func start() async throws {
        guard state == nil else {
            logger?.logCritical("server error: already started")
            throw SocketError.unsupportedAddress
        }
        defer { state = nil }
        do {
            let socket = try await preparePoolAndSocket()
            let task = Task { try await start(on: socket, pool: pool) }
            state = (socket: socket, task: task)
            try await task.getValue(cancelling: .whenParentIsCancelled)
        } catch {
            logger?.logCritical("server error: \(error.localizedDescription)")
            if let state = self.state {
                try? state.socket.close()
            }
            throw error
        }
    }

    func preparePoolAndSocket() async throws -> Socket {
        do {
            try await pool.prepare()
            return try makeSocketAndListen()
        } catch {
            logger?.logCritical("server error: \(error.localizedDescription)")
            throw error
        }
    }

    var waiting: Set<Continuation> = []
    private(set) var state: (socket: Socket, task: Task<Void, Error>)? {
        didSet { isListeningDidUpdate(from: oldValue != nil ) }
    }

    /// Stops the server by closing the listening socket and waiting for all connections to disconnect.
    /// - Parameter timeout: Seconds to allow for connections to close before server task is cancelled.
    public func stop(timeout: TimeInterval = 0) async {
        guard let (socket, task) = state else { return }
        state = nil
        try? socket.close()
        for connection in connections {
            await connection.complete()
        }
        try? await task.getValue(cancelling: .afterTimeout(seconds: timeout))
    }

    func makeSocketAndListen() throws -> Socket {
        let socket = try Socket(domain: Int32(address.ss_family))
        try socket.setValue(true, for: .localAddressReuse)
        #if canImport(Darwin)
        try socket.setValue(true, for: .noSIGPIPE)
        #endif
        try socket.bind(to: address)
        try socket.listen()
        logger?.logListening(on: socket)
        return socket
    }

    func start(on socket: Socket, pool: AsyncSocketPool) async throws {
        let asyncSocket = try AsyncSocket(socket: socket, pool: pool)

        return try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await pool.run()
            }
            group.addTask {
                try await self.listenForConnections(on: asyncSocket)
            }
            try await group.next()
        }
    }

    private func listenForConnections(on socket: AsyncSocket) async throws {
#if compiler(>=5.9)
        if #available(macOS 14.0, iOS 17.0, tvOS 17.0, *) {
            try await listenForConnectionsDiscarding(on: socket)
        } else {
            try await listenForConnectionsFallback(on: socket)
        }
#else
            try await listenForConnectionsFallback(on: socket)
#endif
    }

#if compiler(>=5.9)
    @available(macOS 14.0, iOS 17.0, tvOS 17.0, *)
    private func listenForConnectionsDiscarding(on socket: AsyncSocket) async throws {
        try await withThrowingDiscardingTaskGroup { [logger] group in
            for try await socket in socket.sockets {
                group.addTask {
                    await self.handleConnection(HTTPConnection(socket: socket, logger: logger))
                }
            }
        }
        throw SocketError.disconnected
    }
#endif

    @available(macOS, deprecated: 17.0, renamed: "listenForConnectionsDiscarding(on:)")
    @available(iOS, deprecated: 17.0, renamed: "listenForConnectionsDiscarding(on:)")
    @available(tvOS, deprecated: 17.0, renamed: "listenForConnectionsDiscarding(on:)")
    private func listenForConnectionsFallback(on socket: AsyncSocket) async throws {
        try await withThrowingTaskGroup(of: Void.self) { [logger] group in
            for try await socket in socket.sockets {
                group.addTask {
                    await self.handleConnection(HTTPConnection(socket: socket, logger: logger))
                }
            }
        }
        throw SocketError.disconnected
    }

    private(set) var connections: Set<HTTPConnection> = []

    private func handleConnection(_ connection: HTTPConnection) async {
        logger?.logOpenConnection(connection)
        connections.insert(connection)
        do {
            for try await request in connection.requests {
                logger?.logRequest(request, on: connection)
                let response = await handleRequest(request)
                try await request.bodySequence.flushIfNeeded()
                try await connection.sendResponse(response)
            }
        } catch {
            logger?.logError(error, on: connection)
        }
        connections.remove(connection)
        try? connection.close()
        logger?.logCloseConnection(connection)
    }

    func handleRequest(_ request: HTTPRequest) async -> HTTPResponse {
        var response = await handleRequest(request, timeout: timeout)
        if request.shouldKeepAlive {
            response.headers[.connection] = request.headers[.connection]
        }
        return response
    }

    func handleRequest(_ request: HTTPRequest, timeout: TimeInterval) async -> HTTPResponse {
        do {
            return try await withThrowingTimeout(seconds: timeout) { [handlers] in
                try await handlers.handleRequest(request)
            }
        } catch is HTTPUnhandledError {
            logger?.logError("unhandled request")
            return HTTPResponse(statusCode: .notFound)
        }
        catch {
            logger?.logError("handler error: \(error.localizedDescription)")
            return HTTPResponse(statusCode: .internalServerError)
        }
    }

    private static func makeRootHandler(to handler: HTTPHandler?) -> RoutedHTTPHandler {
        var root = RoutedHTTPHandler()
        if let handler = handler {
            root.appendRoute("*", to: handler)
        }
        return root
    }

    public static func defaultPool(logger: Logging? = nil) -> AsyncSocketPool {
#if canImport(Darwin)
        return .kQueue(logger: logger)
#elseif canImport(CSystemLinux)
        return .ePoll(logger: logger)
#else
        return .poll(logger: logger)
#endif
    }
}

public extension HTTPServer {

#if compiler(>=5.7)
    init(port: UInt16,
         timeout: TimeInterval = 15,
         pool: AsyncSocketPool = defaultPool(),
         logger: Logging? = defaultLogger(),
         handler: HTTPHandler? = nil) {
#if canImport(WinSDK)
        let address = sockaddr_in.inet(port: port)
#else
        let address = sockaddr_in6.inet6(port: port)
#endif
        self.init(address: address,
                  timeout: timeout,
                  pool: pool,
                  logger: logger,
                  handler: handler)
    }

    init(port: UInt16,
         timeout: TimeInterval = 15,
         pool: AsyncSocketPool = defaultPool(),
         logger: Logging? = defaultLogger(),
         handler: @Sendable @escaping (HTTPRequest) async throws -> HTTPResponse) {
        self.init(port: port,
                  timeout: timeout,
                  pool: pool,
                  logger: logger,
                  handler: ClosureHTTPHandler(handler))
    }

#else
    convenience init(port: UInt16,
                     timeout: TimeInterval = 15,
                     pool: AsyncSocketPool = defaultPool(),
                     logger: Logging? = defaultLogger(),
                     handler: HTTPHandler? = nil) {
#if canImport(WinSDK)
        let address = sockaddr_in.inet(port: port)
#else
        let address = sockaddr_in6.inet6(port: port)
#endif
        self.init(address: address,
                  timeout: timeout,
                  pool: pool,
                  logger: logger,
                  handler: handler)
    }

    convenience init(port: UInt16,
                     timeout: TimeInterval = 15,
                     pool: AsyncSocketPool = defaultPool(),
                     logger: Logging? = defaultLogger(),
                     handler: @Sendable @escaping (HTTPRequest) async throws -> HTTPResponse) {
        self.init(port: port,
                  timeout: timeout,
                  pool: pool,
                  logger: logger,
                  handler: ClosureHTTPHandler(handler))
    }
#endif
}

extension Logging {

    func logOpenConnection(_ connection: HTTPConnection) {
        logInfo("\(connection.identifer) open connection")
    }

    func logCloseConnection(_ connection: HTTPConnection) {
        logInfo("\(connection.identifer) close connection")
    }

    func logSwitchProtocol(_ connection: HTTPConnection, to protocol: String) {
        logInfo("\(connection.identifer) switching protocol to \(`protocol`)")
    }

    func logRequest(_ request: HTTPRequest, on connection: HTTPConnection) {
        logInfo("\(connection.identifer) request: \(request.method.rawValue) \(request.path)")
    }

    func logError(_ error: Error, on connection: HTTPConnection) {
        logError("\(connection.identifer) error: \(error.localizedDescription)")
    }

    func logListening(on socket: Socket) {
        logInfo(Self.makeListening(on: try? socket.sockname()))
    }

    static func makeListening(on addr: Socket.Address?) -> String {
        var comps = ["starting server"]
        guard let addr = addr else {
            return comps.joined()
        }

        switch addr {
        case let .ip4(address, port: port):
            if address == "0.0.0.0" {
                comps.append("port: \(port)")
            } else {
                comps.append("\(address):\(port)")
            }
        case let .ip6(address, port: port):
            if address == "::" {
                comps.append("port: \(port)")
            } else {
                comps.append("\(address):\(port)")
            }
        case let .unix(path):
            comps.append("path: \(path)")
        }
        return comps.joined(separator: " ")
    }
}

private extension HTTPConnection {
    var identifer: String {
        "<\(hostname)>"
    }
}
