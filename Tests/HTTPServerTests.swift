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
        await server.appendRoute("*", to: .file(named: "fish.json", in: .module))
        let task = Task { try await server.start() }

        let request = URLRequest(url: URL(string: "http://localhost:8009")!)
        let (data, _) = try await URLSession.shared.makeData(for: request)

        XCTAssertEqual(
            data,
            #"{"fish": "cakes"}"#.data(using: .utf8)
        )
        task.cancel()
    }

    func testServer_StartsOnUnixSocket() async throws {
        var address = sockaddr_un.makeUnix(path: "flyingfox")
        _ = Socket.unlink(&address.sun_path.0)
        let server = HTTPServer.make(address: address)
        await server.appendRoute("*") { _ in
            return HTTPResponse.make(statusCode: .accepted)
        }
        let task = try await server.startDetached()
        let socket = try await AsyncSocket(connectedTo: address, pool: .polling)
        try await socket.writeRequest(.make())

        await XCTAssertEqualAsync(
            try await socket.readResponse().statusCode,
            .accepted
        )
        task.cancel()
    }

    func testServer_StartsOnIP4Socket() async throws {
        let server = HTTPServer.make(address: .makeINET(port: 8080))
        await server.appendRoute("*") { _ in
            return HTTPResponse.make(statusCode: .accepted)
        }
        let task = try await server.startDetached()
        let address = try Socket.makeAddressINET(fromIP4: "127.0.0.1", port: 8080)
        let socket = try await AsyncSocket(connectedTo: address, pool: .polling)
        try await socket.writeRequest(.make())

        await XCTAssertEqualAsync(
            try await socket.readResponse().statusCode,
            .accepted
        )
        try? socket.close()
        task.cancel()
        try? await task.value
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
        var addr = Socket.makeAddressINET6(port: 1234)
        addr.sin6_addr = try Socket.makeInAddr(fromIP6: "::1")
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
