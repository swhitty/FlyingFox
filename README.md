[![Platforms](https://img.shields.io/badge/platforms-iOS%20|%20Mac%20-lightgray.svg)]()
[![Swift 5.5](https://img.shields.io/badge/swift-5.5-red.svg?style=flat)](https://developer.apple.com/swift)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://opensource.org/licenses/MIT)
[![Twitter](https://img.shields.io/badge/twitter-@simonwhitty-blue.svg)](http://twitter.com/simonwhitty)

- [Usage](#usage)
- [Credits](#credits)

# Introduction

**FlyingFox** is a lightweight HTTP server built using [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html). The server uses non blocking sockets, handling each connection in a [Task](https://developer.apple.com/documentation/swift/task) on the default concurrent executor.

# Installation

FlyingFox can be installed by using Swift Package Manager.

**Note:** FlyingFox requires Xcode 13+ to build, and runs on iOS 13+ or macOS 10.15+.

To install using Swift Package Manager, add this to the `dependencies:` section in your Package.swift file:

```swift
.package(url: "https://github.com/swhitty/FlyingFox.git", .upToNextMajor(from: "0.1.0")),
```

# Usage

Start the server by providing a port number:

```swift
import FlyingFox

let server = HTTPServer(port: 8080)
try await server.start()
```

The server runs within the the current task. To stop the server, cancel the task;

```swift
let task = Task { try await server.start() }

task.cancel()
```

## Handlers

Handlers can be added to the server for a corresponding route:

```swift
await server.appendHandler(for: "/hello") { request in 
    try await Task.sleep(nanoseconds: 1_000_000_000)
    return HTTPResponse(statusCode: .ok,
                        body: "Hello World!".data(using: .utf8)!)
}
```

Incoming requests are routed to the first handler with a matching route.

Any unmatched requests receive `HTTP 404`.

### FileHTTPHandler

Requests can be routed to static files via `FileHTTPHandler`:

```swift
await server.appendHandler(for: "GET /mock", handler: .file(named: "mock.json"))
```

`FileHTTPHandler` will return `HTTP 404` if the file does not exist.

### ProxyHTTPHandler

Requests can be proxied via a base URL:

```swift
await server.appendHandler(for: "GET *", handler: .proxy(via: "https://httpstat.us"))
// GET /202?sleep=1000  ---->  https://httpstat.us/202?sleep=1000
```

### Wildcards

Routes can include wildcards which can be pattern matched against paths:

```swift
let HTTPRoute("/hello/*/world")

route ~= "/hello/fish/world" // true
route ~= "GET /hello/fish/world" // true
route ~= "POST hello/dog/world/" // true
route ~= "/hello/world" // false
```

By default routes accept all HTTP methods, but specific methods can be supplied;

```swift
let HTTPRoute("GET /hello/world")

route ~= "GET /hello/world" // true
route ~= "PUT /hello/world" // false
```

## AsyncSocket / PollingSocketPool

Internally, FlyingFox uses standard BSD sockets configured with the flag `O_NONBLOCK`. When data is unavailable for a socket (`EWOULDBLOCK`) the task is suspended using the current `AsyncSocketPool` until data is available:

```swift
protocol AsyncSocketPool {
  func suspend(untilReady socket: Socket) async throws
}
```

`PollingSocketPool` is currently the only pool available. It uses a continuous loop of [`poll(2)`](https://www.freebsd.org/cgi/man.cgi?poll) / [`Task.yield()`](https://developer.apple.com/documentation/swift/task/3814840-yield) to check all sockets awaiting data at a supplied interval.  All sockets share the same pool.

# Credits

FlyingFox is primarily the work of [Simon Whitty](https://github.com/swhitty).

([Full list of contributors](https://github.com/swhitty/FlyingFox/graphs/contributors))
