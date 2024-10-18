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
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing

actor HTTPServerTests {

    private var stopServer: HTTPServer?

    func startServerWithPort(_ server: HTTPServer, preferConnectionsDiscarding: Bool = true) async throws -> UInt16 {
        self.stopServer = server
        Task {
            try await HTTPServer.$preferConnectionsDiscarding.withValue(preferConnectionsDiscarding) {
                try await server.run()
            }
        }
        return try await server.waitForListeningPort()
    }

    @discardableResult
    func startServer(_ server: HTTPServer) async throws -> Task<Void, any Error> {
        self.stopServer = server
        let task = Task { try await server.run() }
        try await server.waitUntilListening()
        return task
    }

    deinit {
        Task { [stopServer] in await stopServer?.stop(timeout: 0) }
    }

    @Test
    func throwsError_WhenAlreadyStarted() async throws {
        let server = HTTPServer.make()
        try await startServer(server)

        await #expect(throws: SocketError.unsupportedAddress) {
            try await server.run()
        }
    }

    @Test
    func waitsUntilListening() async throws {
        let server = HTTPServer.make()
        let task = Task { try await server.waitUntilListening() }
        try await Task.sleep(seconds: 0.1)

        try await startServer(server)

        await #expect(throws: Never.self) {
            try await task.result.get()
        }
    }

    @Test
    func throwsError_WhenSocketAlreadyListening() async throws {
        let server = HTTPServer.make(port: 42185)
        let socket = try await server.makeSocketAndListen()
        defer { try! socket.close() }

        await #expect(throws: SocketError.self) {
            try await server.run()
        }
//        await AsyncAssertThrowsError(try await server.run(), of: SocketError.self) {
//            XCTAssertTrue(
//                $0.errorDescription?.contains("Address already in use") == true
//            )
//        }
    }

    @Test
    func restarts_AfterStopped() async throws {
        let server = HTTPServer.make()
        try await startServer(server)
        await server.stop()

        let task = Task { try await startServer(server) }
        await #expect(throws: Never.self) {
            try await task.value
        }
    }

    @Test
    func taskCanBeCancelled() async throws {
        let server = HTTPServer.make()
        let task = try await startServer(server)

        task.cancel()

        await #expect(throws: (any Error).self) {
            try await task.value
        }
    }

    @Test
    func taskCanBeCancelled_AfterServerIsStopped() async throws {
        let server = HTTPServer.make()
        let task = try await startServer(server)

        await server.stop()
        task.cancel()

        await #expect(throws: (any Error).self) {
            try await task.value
        }
    }

    @Test
    func requests_AreMatchedToHandlers_ViaRoute() async throws {
        let server = HTTPServer.make()

        await server.appendRoute("/accepted") { _ in
            HTTPResponse.make(statusCode: .accepted)
        }
        await server.appendRoute("/gone") { _ in
            HTTPResponse.make(statusCode: .gone)
        }

        var response = await server.handleRequest(.make(method: .GET, path: "/accepted"))
        #expect(
            response.statusCode == .accepted
        )

        response = await server.handleRequest(.make(method: .GET, path: "/gone"))
        #expect(
            response.statusCode == .gone
        )
    }

    @Test
    func unmatchedRequests_Return404() async throws {
        let server = HTTPServer.make()

        let response = await server.handleRequest(.make(method: .GET, path: "/accepted"))
        #expect(
            response.statusCode == .notFound
        )
    }

    @Test
    func connections_AreHandled_DiscardingTaskGroup() async throws {
        let server = HTTPServer.make()
        let port = try await startServerWithPort(server, preferConnectionsDiscarding: true)

        let request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)")!)
        let (_, response) = try await URLSession.shared.data(for: request)

        #expect(
            (response as? HTTPURLResponse)?.statusCode == 404
        )
    }

    @Test
    func connections_AreHandled_FallbackTaskGroup() async throws {
        let server = HTTPServer.make()
        let port = try await startServerWithPort(server, preferConnectionsDiscarding: false)

        let request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)")!)
        let (_, response) = try await URLSession.shared.data(for: request)

        #expect(
            (response as? HTTPURLResponse)?.statusCode == 404
        )
    }

    @Test
    func handlerErrors_Return500() async throws {
        let server = HTTPServer.make() { _ in
            throw SocketError.disconnected
        }

        let response = await server.handleRequest(.make(method: .GET, path: "/accepted"))
        #expect(
            response.statusCode == .internalServerError
        )
    }

    @Test
    func handlerTimeout_Returns500() async throws {
        let server = HTTPServer.make(timeout: 0.1) { _ in
            try await Task.sleep(seconds: 1)
            return HTTPResponse.make(statusCode: .accepted)
        }

        let response = await server.handleRequest(.make(method: .GET, path: "/accepted"))
        #expect(
            response.statusCode == .internalServerError
        )
    }

    @Test
    func keepAlive_IsAddedToResponses() async throws {
        let server = HTTPServer.make()

        var response = await server.handleRequest(
            .make(method: .GET, path: "/accepted", headers: [.connection: "keep-alive"])
        )
        #expect(
            response.shouldKeepAlive
        )

        response = await server.handleRequest(
            .make(method: .GET, path: "/accepted")
        )
        #expect(
            !response.shouldKeepAlive
        )
    }

#if canImport(Darwin)
    @Test
    func server_ReturnsWebSocketFramesToURLSession() async throws {
        try await Task.sleep(seconds: 0.3)
        let server = HTTPServer.make(address: .loopback(port: 0))
        await server.appendRoute("GET /socket", to: .webSocket(EchoWSMessageHandler()))
        let port = try await startServerWithPort(server)

        let wsTask = URLSession.shared.webSocketTask(with: URL(string: "ws://localhost:\(port)/socket")!)
        wsTask.resume()
        try await wsTask.send(.string("Hello"))
        #expect(try await wsTask.receive() == .string("Hello"))
    }
#endif

    @Test
    func server_ReturnsWebSocketFrames() async throws {
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
        #expect(response.headers[.webSocketAccept] == "9twnCz4Oi2Q3EuDqLAETCuip07c=")
        #expect(response.headers[.connection] == "upgrade")
        #expect(response.headers[.upgrade] == "websocket")

        let frame = WSFrame.make(fin: true, opcode: .text, mask: .mock, payload: "FlyingFox".data(using: .utf8)!)
        try await socket.writeFrame(frame)

        #expect(
            try await socket.readFrame() == WSFrame(
                fin: true,
                opcode: .text,
                mask: nil,
                payload: "FlyingFox".data(using: .utf8)!
            )
        )
    }

#if canImport(Darwin)
    @Test
    func defaultLogger_IsOSLog() async throws {
        if #available(iOS 14.0, tvOS 14.0, *) {
            #expect(HTTPServer.defaultLogger() is OSLogHTTPLogging)
        }
    }
#endif

    @Test
    func server_StartsOnUnixSocket() async throws {
        let address = sockaddr_un.unix(path: #function)
        try? Socket.unlink(address)
        let server = HTTPServer.make(address: address)
        await server.appendRoute("*") { _ in
            return HTTPResponse.make(statusCode: .accepted)
        }
        try await startServer(server)

        let socket = try await AsyncSocket.connected(to: address)
        defer { try? socket.close() }
        try await socket.writeRequest(.make())

        #expect(
            try await socket.readResponse().statusCode == .accepted
        )
    }

    @Test
    func server_StartsOnIP4Socket() async throws {
        let server = HTTPServer.make(address: .inet(port: 0))
        await server.appendRoute("*") { _ in
            return HTTPResponse.make(statusCode: .accepted)
        }
        let port = try await startServerWithPort(server)

        let socket = try await AsyncSocket.connected(to: .inet(ip4: "127.0.0.1", port: port))
        defer { try? socket.close() }

        try await socket.writeRequest(.make())

        #expect(
            try await socket.readResponse().statusCode == .accepted
        )
    }

    @Test
    func server_AllowsExistingConnectionsToDisconnect_WhenStopped() async throws {
        let server = HTTPServer.make()
        await server.appendRoute("*") { _ in
            try await Task.sleep(seconds: 0.5)
            return .make(statusCode: .ok)
        }
        let port = try await startServerWithPort(server)
        let socket = try await AsyncSocket.connected(to: .inet(ip4: "127.0.0.1", port: port))
        defer { try? socket.close() }

        try await socket.writeRequest(.make())
        try await Task.sleep(seconds: 0.1)
        let taskStop = Task { await server.stop(timeout: 1) }

        #expect(
            try await socket.readResponse().statusCode == .ok
        )
        await taskStop.value
    }

    @Test
    func server_DisconnectsWaitingRequests_WhenStopped() async throws {
        let server = HTTPServer.make()

        let port = try await startServerWithPort(server)
        let socket = try await AsyncSocket.connected(to: .inet(ip4: "127.0.0.1", port: port))
        defer { try? socket.close() }

        try await Task.sleep(seconds: 0.1)
        #expect(await server.connections.count == 1)

        let taskStop = Task { await server.stop(timeout: 1) }
        try await Task.sleep(seconds: 0.5)

        #expect(await server.connections.count == 0)
        await taskStop.value
    }

    @Test
    func server_Returns500_WhenHandlerTimesout() async throws {
        let server = HTTPServer.make(timeout: 0.5)
        await server.appendRoute("*") { _ in
            try await Task.sleep(seconds: 5)
            return .make(statusCode: .ok)
        }
        let port = try await startServerWithPort(server)

        let request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)")!)
        let (_, response) = try await URLSession.shared.data(for: request)

        #expect(
            (response as? HTTPURLResponse)?.statusCode == 500
        )
    }

    @Test
    func server_ListeningAddress_IP6() async throws {
        let server = HTTPServer.make(address: .inet6(port: 5191))
        try await startServer(server)
        #expect(
            await server.listeningAddress == .ip6("::", port: 5191)
        )
    }

#if canImport(Darwin)
    // docker containers don't like loopback
    @Test
    func server_ListeningAddress_Loopback() async throws {
        let server = HTTPServer.make(address: .loopback(port: 0))
        try await startServer(server)
        #expect(
            await server.listeningAddress != nil
        )
    }
#endif

    @Test
    func defaultLoggerFallback_IsPrintLogger() async throws {
        #expect(HTTPServer.defaultLogger(forceFallback: true) is PrintLogger)
    }

    @Test
    func waitUntilListing_WaitsUntil_SocketIsListening() async throws {
        let server = HTTPServer.make()

        let waiting = Task<Bool, any Error> {
            try await server.waitUntilListening()
            return true
        }

        Task { try await server.run() }
        self.stopServer = server

        #expect(try await waiting.value == true)
    }

    @Test
    func waitUntilListing_ThrowsWhen_TaskIsCancelled() async {
        let server = HTTPServer.make()

        let waiting = Task<Bool, any Error> {
            try await server.waitUntilListening()
            return true
        }

        waiting.cancel()
        await #expect(throws: CancellationError.self) {
            try await waiting.value
        }
    }

    @Test
    func waitUntilListing_ThrowsWhen_TimeoutExpires() async throws {
        let server = HTTPServer.make()

        let waiting = Task<Bool, any Error> {
            try await server.waitUntilListening(timeout: 0.1)
            return true
        }

        await #expect(throws: (any Error).self) {
            try await waiting.value
        }
    }

    @Test
    func routes_To_ParamaterPackWithRequest() async throws {
        let server = HTTPServer.make()
        await server.appendRoute("/fish/:id") { (request: HTTPRequest, id: String) in
            HTTPResponse.make(statusCode: .ok, body: "Hello \(id)".data(using: .utf8)!)
        }
        await server.appendRoute("/chips/:id") { (id: String) in
            HTTPResponse.make(statusCode: .ok, body: "Hello \(id)".data(using: .utf8)!)
        }
        let port = try await startServerWithPort(server)

        let socket = try await AsyncSocket.connected(to: .inet(ip4: "127.0.0.1", port: port))
        defer { try? socket.close() }

        try await socket.writeRequest(.make("/fish/🐟", headers: [.connection: "keep-alive"]))

        #expect(
            try await socket.readResponse().bodyString == "Hello 🐟"
        )

        try await socket.writeRequest(.make("/chips/🍟"))

        #expect(
            try await socket.readResponse().bodyString == "Hello 🍟"
        )
    }

    @Test
    func requests_IncludeRemoteAddress() async throws {
        let server = HTTPServer.make()

        await server.appendRoute("/echo") { req in
            HTTPResponse.make(statusCode: .ok, body: (req.remoteIPAddress ?? "nil").data(using: .utf8)!)
        }

        let port = try await startServerWithPort(server)

        let socket = try await AsyncSocket.connected(to: .inet(ip4: "127.0.0.1", port: port))
        defer { try? socket.close() }

        try await socket.writeRequest(.make("/echo"))
        #expect(
            try await socket.readResponse().bodyString != "nil"
        )
    }
}

extension HTTPServer {

    static func make(address: some SocketAddress,
                     timeout: TimeInterval = 15,
                     logger: any Logging = .disabled,
                     handler: (any HTTPHandler)? = nil) -> HTTPServer {
        HTTPServer(address: address,
                   timeout: timeout,
                   logger: logger,
                   handler: handler)
    }

    static func make(port: UInt16 = 0,
                     timeout: TimeInterval = 15,
                     logger: some Logging = .disabled,
                     handler: (any HTTPHandler)? = nil) -> HTTPServer {
        HTTPServer(port: port,
                   timeout: timeout,
                   logger: logger,
                   handler: handler)
    }

    static func make(port: UInt16 = 0,
                     timeout: TimeInterval = 15,
                     logger: some Logging = .disabled,
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
extension URLSessionWebSocketTask.Message {
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
#if compiler(>=6)
extension URLSessionWebSocketTask.Message: @retroactive Equatable { }
#else
extension URLSessionWebSocketTask.Message: Equatable { }
#endif
#endif

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: TimeInterval) async throws {
        try await sleep(nanoseconds: UInt64(1_000_000_000 * seconds))
    }
}

