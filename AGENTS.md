# AGENTS.md

Notes for coding agents and contributors working in this repository.

## Layout

One Swift package with two library products:

- **FlyingSocks** (`FlyingSocks/Sources`): a cross-platform async socket layer. It has `Socket`, `AsyncSocket` and `SocketPool`, with an event queue per platform: `kQueue` on Darwin, `ePoll` on Linux and Android, and `Poll` elsewhere (Windows).
- **FlyingFox** (`FlyingFox/Sources`): an HTTP server and client built on FlyingSocks, with WebSocket support.

Tests use Swift Testing and live in `FlyingSocks/Tests` and `FlyingFox/Tests`. `CSystemLinux` is a system library target for epoll and eventfd on Linux and Android.

## Supported toolchains

- `swift-tools-version:6.0`, so code must build with Swift 6.0 and 6.1 as well as current releases.
- Don't use syntax that needs a newer compiler, such as the `unsafe` expression from strict memory safety (Swift 6.2), unless it's wrapped in `#if compiler(>=6.2)`.
- CI (`.github/workflows/build.yml`) builds and tests on:
  - Xcode 27, 26.6, 26.2, 16.4 and 16.2
  - Linux Swift 6.0, 6.1, 6.2, 6.3 and 6.4
  - Windows Swift 6.4
- CI also builds, but doesn't test:
  - the static Linux SDK (musl)
  - Android with the swift.org 6.4.2 SDK

## Building and testing

```bash
swift build --build-tests
timeout 60 swift test --skip-build
```

Build first, then run the tests with `--skip-build` under a timeout. The whole suite takes about a second, so any run longer than about 10 seconds is a hang. Find the stuck test rather than waiting.

### Linux tests on macOS with `container`

Use Apple's [`container`](https://github.com/apple/container) tool to run the Linux suite from a Mac:

```bash
container run --rm --mount src="$(pwd)",target=/flyingfox,type=bind swift:6.4 \
  bash -c 'cd /flyingfox && swift build --build-tests --scratch-path /tmp/build && timeout 60 swift test --skip-build --scratch-path /tmp/build'
```

- `--scratch-path /tmp/build` keeps Linux build products out of the shared `.build` directory used by macOS builds.
- Leave out `-it` when there's no terminal, for example when an agent or script runs it. `container run -it` fails without a TTY.
- `./container-run-tests.sh` runs the same suite interactively (with `-it`) on `swift:6.4`.
- Swap the image tag (`swift:6.2`, `swift:6.3` …) to test another toolchain. The first pull of an image takes a minute or two.

### Finding a hanging test

- `swift test` buffers its console output, so when a hung run is killed, the last results you see aren't reliable.
- Pass `--event-stream-output-path <file> --experimental-event-stream-version 0` to get a JSON line per event. While the run is still going, SwiftPM writes these to a temporary `event-stream-*.jsonl` file (find it with `lsof -p <pid>` on the `swiftpm-testing-helper` process). It only copies the file to your path at the end.
- A test with a `testStarted` event and no `testEnded` is the stuck one.
- `sample <pid>` on macOS shows where each thread is waiting.

### Known flaky tests

- `WSFrameEncoderTests.webSocketConnectionToVI` connects to an external server (ws.vi-server.org) and can fail without network access.

If it fails, run it on `main` before blaming your change.

## Concurrency primitives

### `Mutex`

`FlyingSocks/Sources/Mutex.swift`:

- **Darwin:** a backport, because `Synchronization.Mutex` needs macOS 15, iOS 18, tvOS 18, watchOS 11 and visionOS 2.
- **Swift 6.0 on other platforms:** also the backport, because the 6.0 compiler crashes when a generic class stores a `Synchronization.Mutex`.
- **Everywhere else (Swift 6.1 and later):** `Mutex` is a typealias for `Synchronization.Mutex`.

What this means in practice:

- Store a `Mutex` in a `let`. `Synchronization.Mutex` can't be a `var`.
- Only `withLock` and `copy()` are available on every platform. Don't add API that only the backport has.
- A file that uses `Mutex` from `@inlinable` code must import `Synchronization` wherever the typealias applies (see `IdentifiableContinuation.swift`).

### `Disconnected`

`FlyingSocks/Sources/Disconnected.swift` mirrors the `Disconnected` type from [SE-0538](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0538-disconnected.md), which arrives in the Synchronization module with Swift 6.5. Replace it with the standard library type once the minimum supported Swift version includes it.

- Use it to store a non-`Sendable` value, for example in an actor, so it can later be taken out and sent across an isolation boundary. `AsyncBufferingSequence` and `AsyncSharedReplaySequence` store their base iterators this way, so they can call the iterator's async `nextBuffer` away from the actor.
- Values only go in and out through `sending`, so the compiler checks the value really is disconnected. Prefer it to unchecked `@unchecked Sendable` boxes.
- It's `~Copyable`, so it can't be a `Task`'s result type. `withDeadline` uses a private `UncheckedSendable` box for that one case.

### `withDeadline`

`FlyingSocks/Sources/withDeadline.swift` is a backport of `withDeadline` from [SE-0526](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0526-deadline.md). Use it for any time limit.

- **No timeout error.** When the deadline expires, the body is cancelled, and `withDeadline` returns or throws whatever the body does, usually `CancellationError`.
- **Reporting `SocketError.timeout` is the caller's job.** Where public API promises it, the caller maps `CancellationError` itself:

  ```swift
  do {
      return try await withDeadline(in: timeout) { ... }
  } catch is CancellationError where !Task.isCancelled {
      throw SocketError.makeTaskTimeout(seconds: timeout)
  }
  ```

  `AsyncSocket.connected(to:timeout:)` and `HTTPServer.waitUntilListening(timeout:)` do this.
- **It differs from the proposal so it builds with Swift 6.0 and the package's deployment targets:**
  - the body runs in a child task that inherits the caller's isolation (`isolation: isolated (any Actor)? = #isolation` stands in for `nonisolated(nonsending)`)
  - untyped `throws`, and a Copyable `Return`
  - `withDeadline(in: TimeInterval)` for platforms older than `Clock` and `Duration`; the `Clock` and `Duration` forms need macOS 13 or iOS 16

## Socket pools and event queues

`SocketPool` runs `EventQueue.getNotifications()` (a blocking `kevent` or `epoll_wait`) on its own serial `DispatchQueue`, using a copy of the queue struct.

- **`stop()`** must wake a pending or in-progress wait without closing anything. `ePoll` writes to an eventfd canary.
- **`close()`** releases the descriptors, once no wait can still be using them.
- **Never close a descriptor that another thread may be about to use.** The kernel reuses descriptor numbers at once, so a stale `kevent` or `epoll_wait` call would then act on another queue or socket. This has caused hangs before.
- **A socket closed while registered leaves kqueue or epoll silently, without an event.** `AsyncSocket.close()` removes the socket from the pool, which wakes anything suspended on it, before it closes the descriptor.

## Conventions

- Source files start with the MIT licence header used across the repository.
- Use `package` access for API shared between FlyingSocks and FlyingFox that isn't meant to be public.
- Comments that implement HTTP or WebSocket behaviour cite the RFC section, for example `RFC 9112 §6.3`.
- Keep pull requests to one concern. Unrelated fixes, such as CI changes or a bug found along the way, go in their own PR.
