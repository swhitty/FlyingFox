[![Build](https://github.com/swhitty/FlyingFox/actions/workflows/build.yml/badge.svg)](https://github.com/swhitty/FlyingFox/actions/workflows/build.yml)
[![Codecov](https://codecov.io/gh/swhitty/FlyingFox/graphs/badge.svg)](https://codecov.io/gh/swhitty/FlyingFox)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20|%20Mac%20|%20tvOS%20|%20Linux-lightgray.svg)](https://github.com/swhitty/FlyingFox/blob/main/Package.swift)
[![Swift 5.5](https://img.shields.io/badge/swift-5.5-red.svg?style=flat)](https://developer.apple.com/swift)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://opensource.org/licenses/MIT)
[![Twitter](https://img.shields.io/badge/twitter-@simonwhitty-blue.svg)](http://twitter.com/simonwhitty)

- [Usage](#usage)
- [Credits](#credits)

# Introduction

**FlyingFox** is a lightweight HTTP server built using [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html). The server uses non blocking BSD sockets, handling each connection in a concurrent child [Task](https://developer.apple.com/documentation/swift/task). When a socket is blocked with no data, tasks are suspended using the shared [`AsyncSocketPool`](https://github.com/swhitty/FlyingFox/blob/main/README.md#asyncsocket--pollingsocketpool).

# Installation

FlyingFox can be installed by using Swift Package Manager.

**Note:** FlyingFox requires Swift 5.5 on Xcode 13.2+ or Linux to build. It runs on iOS 13+, tvOS 13+ or macOS 10.15+.

To install using Swift Package Manager, add this to the `dependencies:` section in your Package.swift file:

```swift
.package(url: "https://github.com/swhitty/FlyingFox.git", .upToNextMajor(from: "0.2.0")),
```

# Usage

Start the server by providing a port number:

```swift
import FlyingFox

let server = HTTPServer(port: 8080)
try await server.start()
```

The server runs within the the current task. To stop the server, cancel the task:

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

Incoming requests are routed to the first handler with a matching route. Handlers can throw `HTTPUnhandledError` if after inspecting the request, they cannot handle it. The next matched handler is then used to handle the request.

Unhandled requests receive `HTTP 404`.

### FileHTTPHandler

Requests can be routed to static files via `FileHTTPHandler`:

```swift
await server.appendHandler(for: "GET /mock", handler: .file(named: "mock.json"))
```

`FileHTTPHandler` will return `HTTP 404` if the file does not exist.

### ProxyHTTPHandler

Requests can be proxied via a base URL:

```swift
await server.appendHandler(for: "GET *", handler: .proxy(via: "https://pie.dev"))
// GET /get?fish=chips  ---->  GET https://pie.dev/get?fish=chips
```

### RedirectHTTPHandler

Requests can be redirected to a URL:

```swift
await server.appendHandler(for: "GET /fish/*", handler: .redirect(to: "https://pie.dev/get"))
// GET /fish/chips  --->  HTTP 301
//                        Location: https://pie.dev/get
```

### CompositeHTTPHandler

Multiple handlers can be grouped with requests matched against `HTTPRoute` using `CompositeHTTPHandler`.

```swift
var handlers = CompositeHTTPHandler()
handlers.appendHandler(for: "GET /fish/chips", handler: .file(named: "chips.json"))
handlers.appendHandler(for: "GET /fish/mushy_peas", handler: .file(named: "mushy_peas.json"))
await server.appendHandler(for: "GET /fish/*", handler: handlers)
```

`HTTPUnhandledError` is thrown if `CompositeHTTPHandler` is unable to handle the request with any of its registered handlers.  `HTTP 404` is returned as the response.

### Wildcards

Routes can include wildcards which can be [pattern matched](https://docs.swift.org/swift-book/ReferenceManual/Patterns.html#ID426) against paths:

```swift
let HTTPRoute("/hello/*/world")

route ~= "/hello/fish/world" // true
route ~= "GET /hello/fish/world" // true
route ~= "POST hello/dog/world/" // true
route ~= "/hello/world" // false
```

By default routes accept all HTTP methods, but specific methods can be supplied:

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

## Command line app

An example command line app FlyingFoxCLI is available [here](https://github.com/swhitty/FlyingFoxCLI).

# Credits

FlyingFox is primarily the work of [Simon Whitty](https://github.com/swhitty).

([Full list of contributors](https://github.com/swhitty/FlyingFox/graphs/contributors))
