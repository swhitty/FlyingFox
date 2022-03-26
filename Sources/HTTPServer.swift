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

import Foundation

public final actor HTTPServer {

    private let address: sockaddr_storage
    private let timeout: TimeInterval
    private let logger: HTTPLogging?
    private var handlers: RoutedHTTPHandler

    public init<A: SocketAddress>(address: A,
                                  timeout: TimeInterval = 15,
                                  logger: HTTPLogging? = defaultLogger(),
                                  handler: HTTPHandler? = nil) {
        self.address = address.makeStorage()
        self.timeout = timeout
        self.logger = logger
        self.handlers = Self.makeRootHandler(to: handler)
    }

    public convenience init(port: UInt16,
                            timeout: TimeInterval = 15,
                            logger: HTTPLogging? = defaultLogger(),
                            handler: HTTPHandler? = nil) {
        self.init(address: .inet6(port: port),
                  timeout: timeout,
                  logger: logger,
                  handler: handler)
    }

    public convenience init(port: UInt16,
                            timeout: TimeInterval = 15,
                            logger: HTTPLogging? = defaultLogger(),
                            handler: @Sendable @escaping (HTTPRequest) async throws -> HTTPResponse) {
        self.init(port: port,
                  timeout: timeout,
                  logger: logger,
                  handler: ClosureHTTPHandler(handler))
    }

    public func appendRoute(_ route: HTTPRoute, to handler: HTTPHandler) {
        handlers.appendRoute(route, to: handler)
    }

    public func appendRoute(_ route: HTTPRoute, handler: @Sendable @escaping (HTTPRequest) async throws -> HTTPResponse) {
        handlers.appendRoute(route, handler: handler)
    }

    public func start() async throws {
        let socket = try makeSocketAndListen()
        do {
            try await start(on: socket, pool: PollingSocketPool())
        } catch {
            logger?.logCritical("server error: \(error.localizedDescription)")
            try? socket.close()
            throw error
        }
    }

    func makeSocketAndListen() throws -> Socket {
        let socket = try Socket(domain: Int32(address.ss_family), type: Socket.stream)
        try socket.setValue(true, for: .localAddressReuse)
        #if canImport(Darwin)
        try socket.setValue(true, for: .noSIGPIPE)
        #endif
        try socket.bind(to: address)
        try socket.listen()
        return socket
    }

    func start(on socket: Socket, pool: AsyncSocketPool) async throws {
        let asyncSocket = try AsyncSocket(socket: socket, pool: pool)
        logger?.logListening(on: address)

        return try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await pool.run()
            }
            group.addTask {
                try await self.listenForConnections(on: asyncSocket)
            }
            try await group.waitForAll()
        }
    }

    private func listenForConnections(on socket: AsyncSocket) async throws {
        do {
            try await withThrowingTaskGroup(of: Void.self) { [logger] group in
                for try await socket in socket.sockets {
                    group.addTask {
                        await self.handleConnection(HTTPConnection(socket: socket, logger: logger))
                    }
                }
                group.cancelAll()
            }
        } catch {
            try socket.close()
            throw error
        }
    }

    private func handleConnection(_ connection: HTTPConnection) async {
        logger?.logOpenConnection(connection)
        do {
            for try await request in connection.requests {
                logger?.logRequest(request, on: connection)
                let response = await handleRequest(request)
                try await connection.sendResponse(response)
            }
        } catch {
            logger?.logError(error, on: connection)
        }
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
}

extension HTTPLogging {

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

    func logListening(on address: sockaddr_storage) {
        logInfo(Self.makeListening(on: address))
    }

    static func makeListening(on address: sockaddr_storage) -> String {
        var comps = ["starting server"]
        guard let addr = try? Socket.makeAddress(from: address) else {
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

public extension HTTPServer {

    @available(*, deprecated, renamed: "appendRoute(_:to:)")
    func appendHandler(for route: HTTPRoute, handler: HTTPHandler) {
        appendRoute(route, to: handler)

    }

    @available(*, deprecated, renamed: "appendRoute(_:to:)")
    func appendHandler(for route: HTTPRoute, closure: @Sendable @escaping (HTTPRequest) async throws -> HTTPResponse) {
        appendRoute(route, handler: closure)
    }
}
