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

#if canImport(Darwin) && compiler(>=5.6) && compiler(<5.7)
    func testServer_ReturnsWebSocketFramesToURLSession() async throws {
        let server = HTTPServer.make()

        await server.appendRoute("GET /socket", to: .webSocket(EchoWSMessageHandler()))
        let task = Task { try await server.start() }
        defer { task.cancel() }
        let port = try await server.waitForListeningPort()

        let wsTask = URLSession.shared.webSocketTask(with: URL(string: "ws://localhost:\(port)/socket")!)
        wsTask.resume()

        try await wsTask.send(.string("Hello"))
        await AsyncAssertEqual(try await wsTask.receive(), .string("Hello"))
    }

    func testServer_ReturnsWebSocketFrames() async throws {
        let address = Socket.makeAddressUnix(path: "foxing")
        try? Socket.unlink(address)
        let server = HTTPServer.make(address: address)
        await server.appendRoute("GET /socket", to: .webSocket(EchoWSMessageHandler()))
        let task = Task { try await server.start() }
        defer { task.cancel() }
        try await server.waitUntilListening()

        let socket = try await AsyncSocket.connected(to: address, pool: server.pool)
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

    func testDefaultLogger_IsOSLog() async throws {
        if #available(iOS 14.0, tvOS 14.0, *) {
            XCTAssertTrue(HTTPServer.defaultLogger() is OSLogHTTPLogging)
        }
    }
#endif

#if compiler(>=5.6)
    func testServer_StartsOnUnixSocket() async throws {
        let address = sockaddr_un.unix(path: "foxsocks")
        try? Socket.unlink(address)
        let server = HTTPServer.make(address: address)
        await server.appendRoute("*") { _ in
            return HTTPResponse.make(statusCode: .accepted)
        }
        let task = Task { try await server.start() }
        defer { task.cancel() }
        try await server.waitUntilListening()

        let socket = try await AsyncSocket.connected(to: address, pool: server.pool)
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

        let task = Task { try await server.start() }
        defer { task.cancel() }
        let port = try await server.waitForListeningPort()

        let socket = try await AsyncSocket.connected(to: .inet(ip4: "127.0.0.1", port: port), pool: server.pool)
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
            return .make(statusCode: .ok)
        }
        let task = Task { try await server.start() }
        defer { task.cancel() }
        let port = try await server.waitForListeningPort()

        let socket = try await AsyncSocket.connected(to: .inet(ip4: "127.0.0.1", port: port))
        defer { try? socket.close() }

        try await Task.sleep(seconds: 0.5)
        let taskStop = Task { await server.stop(timeout: 10) }

        try await socket.writeRequest(.make())
        let response = try await socket.readResponse()
        try? socket.close()

        await taskStop.value
        XCTAssertEqual(response.statusCode, .ok)
    }
#endif

    func disabled_testServer_Returns500_WhenHandlerTimesout() async throws {
        let server = HTTPServer.make(timeout: 0.5)
        await server.appendRoute("*") { _ in
            try await Task.sleep(seconds: 5)
            return .make(statusCode: .ok)
        }
        let task = Task { try await server.start() }
        defer { task.cancel() }
        let port = try await server.waitForListeningPort()

        let request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)")!)
        let (_, response) = try await URLSession.shared.makeData(for: request)

        XCTAssertEqual(
            (response as? HTTPURLResponse)?.statusCode,
            500
        )
        task.cancel()
    }


    func testServer_ListeningAddress_IP6() async throws {
        let server = HTTPServer.make(address: .inet6(port: 8080))
        let task = Task { try await server.start() }
        defer { task.cancel() }

        try await server.waitUntilListening()
        await AsyncAssertEqual(
            await server.listeningAddress,
            .ip6("::", port: 8080)
        )
    }

#if canImport(Darwin)
    // docker containers don't like loopback
    func testServer_ListeningAddress_Loopback() async throws {
        let server = HTTPServer.make(address: .loopback(port: 0))
        let task = Task { try await server.start() }
        defer { task.cancel() }

        try await server.waitUntilListening()
        await AsyncAssertNotNil(
            await server.listeningAddress
        )
    }
#endif

    func testDefaultLoggerFallback_IsPrintLogger() async throws {
        XCTAssertTrue(HTTPServer.defaultLogger(forceFallback: true) is PrintHTTPLogger)
    }

    func testListeningLog_INETPort() {
        let addr = Socket.makeAddressINET(port: 1234)
        XCTAssertEqual(
            PrintHTTPLogger.makeListening(on: addr.makeStorage()),
            "starting server port: 1234"
        )
    }

    func testListeningLog_INET() throws {
        let addr = try Socket.makeAddressINET(fromIP4: "8.8.8.8", port: 1234)
        XCTAssertEqual(
            PrintHTTPLogger.makeListening(on: addr.makeStorage()),
            "starting server 8.8.8.8:1234"
        )
    }

    func testListeningLog_INET6Port() {
        let addr = Socket.makeAddressINET6(port: 5678)
        XCTAssertEqual(
            PrintHTTPLogger.makeListening(on: addr.makeStorage()),
            "starting server port: 5678"
        )
    }

    func testListeningLog_INET6() throws {
        let addr = try sockaddr_in6.inet6(ip6: "::1", port: 1234)
        XCTAssertEqual(
            PrintHTTPLogger.makeListening(on: addr.makeStorage()),
            "starting server ::1:1234"
        )
    }

    func testListeningLog_UnixPath() {
        let addr = Socket.makeAddressUnix(path: "/var/fox/xyz")
        XCTAssertEqual(
            PrintHTTPLogger.makeListening(on: addr.makeStorage()),
            "starting server path: /var/fox/xyz"
        )
    }

    func testListeningLog_Invalid() {
        var addr = Socket.makeAddressUnix(path: "/var/fox/xyz")
        addr.sun_family = sa_family_t(AF_IPX)
        XCTAssertEqual(
            PrintHTTPLogger.makeListening(on: addr.makeStorage()),
            "starting server"
        )
    }

    func testWaitUntilListing_WaitsUntil_SocketIsListening() async {
        let server = HTTPServer.make()

        let waiting = Task<Bool, Error> {
            try await server.waitUntilListening()
            return true
        }

        let task = Task { try await server.start() }
        defer { task.cancel() }

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
                                       logger: HTTPLogging? = defaultLogger(),
                                       handler: HTTPHandler? = nil) -> HTTPServer {
        HTTPServer(address: address,
                   timeout: timeout,
                   logger: logger,
                   handler: handler)
    }

    static func make(port: UInt16 = 0,
                     timeout: TimeInterval = 15,
                     logger: HTTPLogging? = defaultLogger(),
                     handler: HTTPHandler? = nil) -> HTTPServer {
        HTTPServer(port: port,
                   timeout: timeout,
                   logger: logger,
                   handler: handler)
    }

    static func make(port: UInt16 = 0,
                     timeout: TimeInterval = 15,
                     logger: HTTPLogging? = .print(),
                     handler: @Sendable @escaping (HTTPRequest) async throws -> HTTPResponse) -> HTTPServer {
        HTTPServer(port: port,
                   timeout: timeout,
                   logger: logger,
                   handler: handler)
    }

    func waitForListeningPort() async throws -> UInt16 {
        try await waitUntilListening(timeout: 10)
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
