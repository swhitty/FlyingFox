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
            try await Task.sleep(nanoseconds: 1_000_000_000)
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

    func testServer_ReturnsFile_WhenFileHandlerIsMatched() async throws {
        let server = HTTPServer.make(port: 8009)
        await server.appendRoute("*", to: .file(named: "Stubs/fish.json", in: .module))
        let task = Task { try await server.start() }

        let request = URLRequest(url: URL(string: "http://localhost:8009")!)
        let (data, _) = try await URLSession.shared.makeData(for: request)

        XCTAssertEqual(
            data,
            #"{"fish": "cakes"}"#.data(using: .utf8)
        )
        task.cancel()
    }

    func testServer_ReturnsFile_WhenDirectoryHandlerIsMatched() async throws {
        let server = HTTPServer.make(port: 8019)
        await server.appendRoute("*", to: .directory(for: .module, subPath: "Stubs", serverPath: "/server/path/"))
        let task = Task { try await server.start() }

        let request = URLRequest(url: URL(string: "http://localhost:8019/server/path/subdir/vinegar.json")!)
        let (data, _) = try await URLSession.shared.makeData(for: request)

        XCTAssertEqual(
            data,
            #"{"type": "malt"}"#.data(using: .utf8)
        )
        task.cancel()
    }

    func testServer_StartsOnUnixSocket() async throws {
        let address = sockaddr_un.unix(path: "fox")
        try? Socket.unlink(address)
        let server = HTTPServer.make(address: address)
        await server.appendRoute("*") { _ in
            return HTTPResponse.make(statusCode: .accepted)
        }
        let task = try await server.startDetached()
        defer { task.cancel() }
        let socket = try await AsyncSocket.connected(to: address, pool: .polling)
        defer { try? socket.close() }
        try await socket.writeRequest(.make())

        await XCTAssertEqualAsync(
            try await socket.readResponse().statusCode,
            .accepted
        )
    }

    func testServer_StartsOnIP4Socket() async throws {
        let server = HTTPServer.make(address: .inet(port: 8080))
        await server.appendRoute("*") { _ in
            return HTTPResponse.make(statusCode: .accepted)
        }

        let task = try await server.startDetached()
        defer { task.cancel( )}

        let socket = try await AsyncSocket.connected(to: .inet(ip4: "127.0.0.1", port: 8080), pool: .polling)
        defer { try? socket.close() }

        try await socket.writeRequest(.make())

        await XCTAssertEqualAsync(
            try await socket.readResponse().statusCode,
            .accepted
        )
    }

#if canImport(Darwin)
    func testServer_Returns500_WhenHandlerTimesout() async throws {
        let server = HTTPServer.make(timeout: 0.1)
        await server.appendRoute("*") { _ in
            try await Task.sleep(nanoseconds: 5_000_000_000)
            return .make(statusCode: .ok)
        }
        let task = Task { try await server.start() }

        let request = URLRequest(url: URL(string: "http://localhost:8008")!)
        let (_, response) = try await URLSession.shared.makeData(for: request)

        XCTAssertEqual(
            (response as? HTTPURLResponse)?.statusCode,
            500
        )
        task.cancel()
    }
#endif

#if canImport(Darwin) && compiler(>=5.6)
    func testServer_ReturnsWebSocketFramesToURLSession() async throws {
        let server = HTTPServer(port: 8080)

        await server.appendRoute("GET /socket", to: .webSocket(EchoWSMessageHandler()))
        let task = try await server.startDetached()
        defer { task.cancel() }

        let wsTask = URLSession.shared.webSocketTask(with: URL(string: "ws://localhost:8080/socket")!)
        wsTask.resume()

        try await wsTask.send(.string("Hello"))
        await XCTAssertEqualAsync(try await wsTask.receive(), .string("Hello"))
    }
#endif

    func testServer_ReturnsWebSocketFrames() async throws {
        let address = Socket.makeAddressUnix(path: "fox")
        try? Socket.unlink(address)
        let server = HTTPServer.make(address: address)
        await server.appendRoute("GET /socket", to: .webSocket(EchoWSMessageHandler()))
        let task = try await server.startDetached()
        defer { task.cancel() }

        let socket = try await AsyncSocket.connected(to: address, pool: .polling)
        defer { try? socket.close() }

        var request = HTTPRequest.make(path: "/socket")
        request.headers[.upgrade] = "websocket"
        request.headers[.connection] = "Upgrade"
        request.headers[.webSocketVersion] = "13"
        request.headers[.webSocketKey] = "ABC"
        try await socket.writeRequest(request)

        let response = try await socket.readResponse()
        XCTAssertEqual(response.headers[.webSocketAccept], "YaxQU85y1o0znnviL0CeoKg7QTM=")
        XCTAssertEqual(response.headers[.connection], "upgrade")
        XCTAssertEqual(response.headers[.upgrade], "websocket")

        let frame = WSFrame.make(fin: true, opcode: .text, mask: .mock, payload: "FlyingFox".data(using: .utf8)!)
        try await socket.writeFrame(frame)

        await XCTAssertEqualAsync(
            try await socket.readFrame(),
            WSFrame(fin: true, opcode: .text, mask: nil, payload: "FlyingFox".data(using: .utf8)!)
        )
    }

#if canImport(Darwin)
    func testDefaultLogger_IsOSLog() async throws {
        XCTAssertTrue(HTTPServer.defaultLogger() is OSLogHTTPLogging)
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
}

extension HTTPHandlerTests {

    func testDeprecatedHandler_AppendsHandler() async throws {
        let server = HTTPServer.make()

        await server.appendHandler(for: "*", handler: .redirect(to: "https://pie.dev"))

        let response = await server.handleRequest(.make(path: "/hello"))
        XCTAssertEqual(response.statusCode, .movedPermanently)
    }

    func testDeprecatedHandler_AppendsClosure() async throws {
        let server = HTTPServer.make()

        await server.appendHandler(for: "/hello") { _ in
            HTTPResponse(statusCode: .ok)
        }

        let response = await server.handleRequest(.make(path: "/hello"))
        XCTAssertEqual(response.statusCode, .ok)
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

    static func make(port: UInt16 = 8008,
                     timeout: TimeInterval = 15,
                     logger: HTTPLogging? = defaultLogger(),
                     handler: HTTPHandler? = nil) -> HTTPServer {
        HTTPServer(port: port,
                   timeout: timeout,
                   logger: logger,
                   handler: handler)
    }

    static func make(port: UInt16 = 8008,
                     timeout: TimeInterval = 15,
                     logger: HTTPLogging? = .print(),
                     handler: @Sendable @escaping (HTTPRequest) async throws -> HTTPResponse) -> HTTPServer {
        HTTPServer(port: port,
                   timeout: timeout,
                   logger: logger,
                   handler: handler)
    }

    // Ensures server is listening before returning
    // clients can then immediatley connect
    func startDetached() throws -> Task<Void, Error>{
        let socket = try makeSocketAndListen()
        let pool = PollingSocketPool()
        return Task {
            defer { try? socket.close() }
            try await start(on: socket, pool: pool)
        }
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
