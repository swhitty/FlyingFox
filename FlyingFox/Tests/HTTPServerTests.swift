//
//  HTTPServerTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 22/02/2022.
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

@testable import FlyingFox
@testable import FlyingSocks
import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class HTTPServerTests: XCTestCase {

    private var stopServer: HTTPServer?

    func startServerWithPort(_ server: HTTPServer) async throws -> UInt16 {
        self.stopServer = server
        Task { try await server.start() }
        return try await server.waitForListeningPort()
    }

    @discardableResult
    func startServer(_ server: HTTPServer) async throws -> Task<Void, Error> {
        self.stopServer = server
        let task = Task { try await server.start() }
        try await server.waitUntilListening()
        return task
    }

    override func tearDown() async throws {
        await stopServer?.stop(timeout: 0)
    }

    func testThrowsError_WhenAlreadyStarted() async throws {
        let server = HTTPServer.make()
        try await startServer(server)

        await AsyncAssertThrowsError(try await server.start(), of: SocketError.self) {
            XCTAssertEqual($0, .unsupportedAddress)
        }
    }

    func testRestarts_AfterStopped() async throws {
        let server = HTTPServer.make()
        try await startServer(server)
        await server.stop()

        await AsyncAssertNoThrow(
            try await startServer(server)
        )
    }

    func testTaskCanBeCancelled() async throws {
        let server = HTTPServer.make()
        let task = try await startServer(server)

        task.cancel()

        await AsyncAssertThrowsError(try await task.value)
    }

    func testTaskCanBeCancelled_AfterServerIsStopped() async throws {
        let server = HTTPServer.make()
        let task = try await startServer(server)

        await server.stop()
        task.cancel()

        await AsyncAssertThrowsError(try await task.value)
    }

    func testRequests_AreMatchedToHandlers_ViaRoute() async throws {
        let server = HTTPServer.make()

        await server.appendRoute("/accepted") { _ in
            HTTPResponse.make(statusCode: .accepted)
        }
        await server.appendRoute("/gone") { _ in
            HTTPResponse.make(statusCode: .gone)
        }

        var response = await server.handleRequest(.make(method: .GET, path: "/accepted"))
        XCTAssertEqual(
            response.statusCode,
            .accepted
        )

        response = await server.handleRequest(.make(method: .GET, path: "/gone"))
        XCTAssertEqual(
            response.statusCode,
            .gone
        )
    }

    func testUnmatchedRequests_Return404() async throws {
        let server = HTTPServer.make()

        let response = await server.handleRequest(.make(method: .GET, path: "/accepted"))
        XCTAssertEqual(
            response.statusCode,
            .notFound
        )
    }

    func testHandlerErrors_Return500() async throws {
        let server = HTTPServer.make() { _ in
            throw SocketError.disconnected
        }

        let response = await server.handleRequest(.make(method: .GET, path: "/accepted"))
        XCTAssertEqual(
            response.statusCode,
            .internalServerError
        )
    }

    func testHandlerTimeout_Returns500() async throws {
        let server = HTTPServer.make(timeout: 0.1) { _ in
            try await Task.sleep(seconds: 1)
            return HTTPResponse.make(statusCode: .accepted)
        }

        let response = await server.handleRequest(.make(method: .GET, path: "/accepted"))
        XCTAssertEqual(
            response.statusCode,
            .internalServerError
        )
    }

    func testKeepAlive_IsAddedToResponses() async throws {
        let server = HTTPServer.make()

        var response = await server.handleRequest(
            .make(method: .GET, path: "/accepted", headers: [.connection: "keep-alive"])
        )
        XCTAssertTrue(
            response.shouldKeepAlive
        )

        response = await server.handleRequest(
            .make(method: .GET, path: "/accepted")
        )
        XCTAssertFalse(
            response.shouldKeepAlive
        )
    }

#if canImport(Darwin) && compiler(>=5.6)
    func testServer_ReturnsWebSocketFramesToURLSession() async throws {
        try await Task.sleep(seconds: 0.3)
        let server = HTTPServer.make(address: .loopback(port: 0))
        await server.appendRoute("GET /socket", to: .webSocket(EchoWSMessageHandler()))
        let port = try await startServerWithPort(server)

        let wsTask = URLSession.shared.webSocketTask(with: URL(string: "ws://localhost:\(port)/socket")!)
        wsTask.resume()
        try await wsTask.send(.string("Hello"))
        await AsyncAssertEqual(try await wsTask.receive(), .string("Hello"))
    }
#endif

    func testServer_ReturnsWebSocketFrames() async throws {
        let address = Socket.makeAddressUnix(path: "foxing")
        try? Socket.unlink(address)
        let server = HTTPServer.make(address: address)
        await server.appendRoute("GET /socket", to: .webSocket(EchoWSMessageHandler()))
        try await startServer(server)

        let socket = try await AsyncSocket.connected(to: address)
        defer { try? socket.close() }

        var request = HTTPRequest.make(path: "/socket")
        request.headers[.host] = "localhost"
        request.headers[.upgrade] = "websocket"
        request.headers[.connection] = "Keep-Alive, Upgrade"
        request.headers[.webSocketVersion] = "13"
        request.headers[.webSocketKey] = "ABCDEFGHIJKLMNOP".data(using: .utf8)!.base64EncodedString()
        try await socket.writeRequest(request)

        let response = try await socket.readResponse()
        XCTAssertEqual(response.headers[.webSocketAccept], "9twnCz4Oi2Q3EuDqLAETCuip07c=")
        XCTAssertEqual(response.headers[.connection], "upgrade")
        XCTAssertEqual(response.headers[.upgrade], "websocket")

        let frame = WSFrame.make(fin: true, opcode: .text, mask: .mock, payload: "FlyingFox".data(using: .utf8)!)
        try await socket.writeFrame(frame)

        await AsyncAssertEqual(
            try await socket.readFrame(),
            WSFrame(fin: true, opcode: .text, mask: nil, payload: "FlyingFox".data(using: .utf8)!)
        )
    }

#if canImport(Darwin)
    func testDefaultLogger_IsOSLog() async throws {
        if #available(iOS 14.0, tvOS 14.0, *) {
            XCTAssertTrue(HTTPServer.defaultLogger() is OSLogHTTPLogging)
        }
    }
#endif

    func testServer_StartsOnUnixSocket() async throws {
        let address = sockaddr_un.unix(path: "foxsocks")
        try? Socket.unlink(address)
        let server = HTTPServer.make(address: address)
        await server.appendRoute("*") { _ in
            return HTTPResponse.make(statusCode: .accepted)
        }
        try await startServer(server)

        let socket = try await AsyncSocket.connected(to: address)
        defer { try? socket.close() }
        try await socket.writeRequest(.make())

        await AsyncAssertEqual(
            try await socket.readResponse().statusCode,
            .accepted
        )
    }

    func testServer_StartsOnIP4Socket() async throws {
        let server = HTTPServer.make(address: .inet(port: 0))
        await server.appendRoute("*") { _ in
            return HTTPResponse.make(statusCode: .accepted)
        }
        let port = try await startServerWithPort(server)

        let socket = try await AsyncSocket.connected(to: .inet(ip4: "127.0.0.1", port: port))
        defer { try? socket.close() }

        try await socket.writeRequest(.make())

        await AsyncAssertEqual(
            try await socket.readResponse().statusCode,
            .accepted
        )
    }

    func testServer_AllowsExistingConnectionsToDisconnect_WhenStopped() async throws {
        let server = HTTPServer.make()
        await server.appendRoute("*") { _ in
            try await Task.sleep(seconds: 2)
            return .make(statusCode: .ok)
        }
        let port = try await startServerWithPort(server)
        let socket = try await AsyncSocket.connected(to: .inet(ip4: "127.0.0.1", port: port))
        defer { try? socket.close() }

        try await socket.writeRequest(.make())
        try await Task.sleep(seconds: 0.5)
        let taskStop = Task { await server.stop(timeout: 5) }

        await AsyncAssertEqual(
            try await socket.readResponse().statusCode,
            .ok
        )
        await taskStop.value
    }

    func testServer_DisconnectsWaitingRequests_WhenStopped() async throws {
        let server = HTTPServer.make(logger: HTTPServer.defaultLogger())

        let port = try await startServerWithPort(server)
        let socket = try await AsyncSocket.connected(to: .inet(ip4: "127.0.0.1", port: port))
        defer { try? socket.close() }

        try await Task.sleep(seconds: 0.5)
        await AsyncAssertEqual(await server.connections.count, 1)

        let taskStop = Task { await server.stop(timeout: 5) }
        try await Task.sleep(seconds: 0.5)

        await AsyncAssertEqual(await server.connections.count, 0)
        await taskStop.value
    }

    func disabled_testServer_Returns500_WhenHandlerTimesout() async throws {
        let server = HTTPServer.make(timeout: 0.5)
        await server.appendRoute("*") { _ in
            try await Task.sleep(seconds: 5)
            return .make(statusCode: .ok)
        }
        let port = try await startServerWithPort(server)

        let request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)")!)
        let (_, response) = try await URLSession.shared.makeData(for: request)

        XCTAssertEqual(
            (response as? HTTPURLResponse)?.statusCode,
            500
        )
    }

    func testServer_ListeningAddress_IP6() async throws {
        let server = HTTPServer.make(address: .inet6(port: 5191))
        try await startServer(server)
        await AsyncAssertEqual(
            await server.listeningAddress,
            .ip6("::", port: 5191)
        )
    }

#if canImport(Darwin)
    // docker containers don't like loopback
    func testServer_ListeningAddress_Loopback() async throws {
        let server = HTTPServer.make(address: .loopback(port: 0))
        try await startServer(server)
        await AsyncAssertNotNil(
            await server.listeningAddress
        )
    }
#endif

    func testDefaultLoggerFallback_IsPrintLogger() async throws {
        XCTAssertTrue(HTTPServer.defaultLogger(forceFallback: true) is PrintLogger)
    }

    func testWaitUntilListing_WaitsUntil_SocketIsListening() async {
        let server = HTTPServer.make()

        let waiting = Task<Bool, Error> {
            try await server.waitUntilListening()
            return true
        }

        Task { try await server.start() }
        self.stopServer = server

        await AsyncAssertEqual(try await waiting.value, true)
    }

    func testWaitUntilListing_ThrowsWhen_TaskIsCancelled() async {
        let server = HTTPServer.make()

        let waiting = Task<Bool, Error> {
            try await server.waitUntilListening()
            return true
        }

        waiting.cancel()
        await AsyncAssertThrowsError(try await waiting.value, of: CancellationError.self)
    }

    func testWaitUntilListing_ThrowsWhen_TimeoutExpires() async throws {
        let server = HTTPServer.make()

        let waiting = Task<Bool, Error> {
            try await server.waitUntilListening(timeout: 1)
            return true
        }

        await AsyncAssertThrowsError(try await waiting.value, of: Error.self)
    }
}

extension HTTPServer {

    static func make<A: SocketAddress>(address: A,
                                       timeout: TimeInterval = 15,
                                       logger: Logging? = defaultLogger(),
                                       handler: HTTPHandler? = nil) -> HTTPServer {
        HTTPServer(address: address,
                   timeout: timeout,
                   logger: logger,
                   handler: handler)
    }

    static func make(port: UInt16 = 0,
                     timeout: TimeInterval = 15,
                     logger: Logging? = nil,
                     handler: HTTPHandler? = nil) -> HTTPServer {
        HTTPServer(port: port,
                   timeout: timeout,
                   logger: logger,
                   handler: handler)
    }

    static func make(port: UInt16 = 0,
                     timeout: TimeInterval = 15,
                     logger: Logging? = nil,
                     handler: @Sendable @escaping (HTTPRequest) async throws -> HTTPResponse) -> HTTPServer {
        HTTPServer(port: port,
                   timeout: timeout,
                   logger: logger,
                   handler: handler)
    }

    func waitForListeningPort(timeout: TimeInterval = 3) async throws -> UInt16 {
        try await waitUntilListening(timeout: timeout)
        switch listeningAddress {
        case let .ip4(_, port: port),
             let .ip6(_, port: port):
            return port
        default:
            throw Error.noPort
        }
    }

    private enum Error: Swift.Error {
        case noPort
    }
}



#if canImport(Darwin)
extension URLSessionWebSocketTask.Message: Equatable {
    public static func == (lhs: URLSessionWebSocketTask.Message, rhs: URLSessionWebSocketTask.Message) -> Bool {
        switch (lhs, rhs) {
        case (.string(let lval), .string(let rval)):
            return lval == rval
        case (.data(let lval), .data(let rval)):
            return lval == rval
        default:
            return false
        }
    }
}
#endif

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: TimeInterval) async throws {
        try await sleep(nanoseconds: UInt64(1_000_000_000 * seconds))
    }
}

