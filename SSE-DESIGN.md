# Server-Sent Events in FlyingFox: design proposal

Status: investigation, with a working prototype on branch `claude/sse-design-ea1c42`
(`FlyingFox/Sources/SSEEvent.swift`, `FlyingFox/Sources/HTTPResponse+SSE.swift`, tests in
`FlyingFox/Tests/SSEEventTests.swift`).

**Short answer:** the starting assumption is right. Over HTTP/1.1, an event stream is an ordinary
`200` response with `Content-Type: text/event-stream` and a chunked body that never ends on its own.
FlyingFox can already send such a body and writes each chunk to the socket as it's produced. What's
missing is the event encoding, a bounded producer, heartbeats, and cancelling the producer when the
client goes away. The prototype adds all of that without changing `HTTPResponse.Payload`.

---

## 1. Protocol notes

Source: WHATWG HTML Living Standard, §9.2 "Server-sent events".

### Response

- **Status and type.** The client accepts only `200` with `Content-Type: text/event-stream`
  (§9.2.3). Any other status or type *fails* the connection, and `EventSource` does not reconnect.
  `204 No Content` is the documented way to tell a client to stop reconnecting. Redirects are
  followed.
- **Encoding.** The stream is always UTF-8. A `charset` parameter is ignored, and one leading BOM
  is stripped (§9.2.5).
- **Caching.** Send `Cache-Control: no-cache`. The spec's examples do, and intermediaries must not
  cache or coalesce the stream. Some proxies buffer responses. nginx, for example, needs
  `X-Accel-Buffering: no`, which the app can pass as a header.
- **Framing (RFC 9112 §6.3, §7.1).** There's no `Content-Length`. On HTTP/1.1 the body is either
  chunked (`Transfer-Encoding: chunked`) or delimited by closing the connection. Browsers handle
  both. The authoring notes (§9.2.7) warn that chunking done by an unaware layer can delay events.
  That's not a problem when, as here, every event is its own chunk and is written immediately.
- **Keep-alive.** The response ends only when the server ends it. The client then reconnects after
  the `retry` delay (default a few seconds, chosen by the user agent). Ending the stream is not
  "done" for the client. To stop it, answer the reconnect with `204`.
- **Idle connections.** Proxies drop idle connections. §9.2.7 recommends a comment line about every
  15 seconds.

### Event fields (§9.2.5 parsing, §9.2.6 interpreting)

- Lines end with CRLF, LF or CR. Only those three: U+2028 and U+0085 are ordinary characters.
- `field: value`. **Exactly one** space after the colon is removed, so writing `field: ` plus the
  value always round-trips a value that itself starts with a space.
- A blank line dispatches the event.
- `data`: each line is appended to the data buffer followed by LF, and the trailing LF is removed
  when the event is dispatched. Multi-line data is therefore sent as one `data:` line per line. An
  event with an empty data buffer is **not dispatched**, but `data:` with an empty value does
  dispatch an empty message.
- `event`: the event type, `message` when absent. A line break in the value would end the field,
  so it must be rejected.
- `id`: sets the last event ID buffer, even on an event that isn't dispatched. An empty value
  resets it. A value containing U+0000 is **ignored**. Line breaks must be rejected.
- `retry`: reconnection time in milliseconds. ASCII digits only, otherwise ignored.
- `:` starts a comment, which is ignored. Use it for heartbeats.
- Unknown fields are ignored.

### Reconnection and `Last-Event-ID` (§9.2.4)

When it reconnects, the client sends `Last-Event-ID: <last id>` if the ID is non-empty. The server
can resume from there. `EventSource` can't set headers on the *first* request, so apps often accept
a query parameter too, for example `?lastEventId=`.

### HTTP/1.1 compared with HTTP/2

- On HTTP/1.1 each `EventSource` holds a whole TCP connection.
- Browsers cap HTTP/1.1 connections at about 6 per origin, so a few tabs with streams can starve
  normal requests to the same origin.
- That connection can't serve anything else until the stream ends (no pipelining past it).
- HTTP/2 multiplexes the stream as one of many streams, and has no chunked encoding.
- FlyingFox is HTTP/1.1 only, so each SSE client costs one socket and one connection task. Document
  the connection limit, and suggest a separate origin or a reverse proxy that terminates HTTP/2.

---

## 2. How FlyingFox handles responses today

### Streaming bodies already work

- `HTTPBodySequence(from: some AsyncBufferedSequence<UInt8>)` sets `count = nil` and wraps the bytes
  in `HTTPChunkedTransferEncoder`, which makes one chunk per `nextBuffer` call.
- `HTTPEncoder` adds `Transfer-Encoding: chunked` when the count is nil.
- `HTTPConnection.sendResponse` writes the header, then calls `socket.write(chunk)` for every
  buffer. There's no output buffering, and accepted TCP sockets have `TCP_NODELAY` set, so each
  chunk goes out as soon as it's produced. An unbounded body is fine.
- **Gap:** the only public streaming initialiser takes an `AsyncBufferedSequence<UInt8>`. That's
  awkward for apps, and there's no `AsyncSequence<Data>` or event-based form.

### The handler timeout doesn't cut off a stream

`HTTPServer.handleRequest(_:timeout:)` wraps only `handlers.handleRequest(request)` in
`withDeadline`, which is the code that *returns* the `HTTPResponse`. The body is iterated later, in
`sendResponse`, outside the deadline. So a handler that returns quickly can stream for as long as it
likes.

The catch is that the producer must be **lazy**: pulled by the body, or an unstructured task. A
producer started as a child task inside the handler, for example in `withTaskGroup`, is awaited or
cancelled when the handler returns. The prototype's `server_streamsEventsBeyondHandlerTimeout` test
uses a 0.1 s timeout and streams for 0.3 s.

### Client disconnect is only noticed on write

While a response is being sent, nobody reads the socket: `handleConnection` serves requests one
after another. A client that closes is noticed only when a write fails. Without heartbeats, a stream
to a client that has gone, with no events to send, lives forever.

When the write does fail, `sendResponse` throws, the body iterator is released and the connection
closes. Nothing cancels the *producer* unless the body's iterator ties its lifetime to it, which the
prototype does.

### `stop()`

- `stop(timeout:)` closes the listening socket, then calls `connection.complete()`.
- `complete()` only stops the connection reading the *next* request, so an in-flight body keeps
  streaming.
- `stop` then waits `timeout` before cancelling the server task. The default `timeout: 0` cancels
  immediately.
- The cancellation reaches the body iteration. In the prototype, `AsyncHandoff.next()` returns nil,
  the terminating chunk is written, and the producer task is cancelled (test
  `server_cancelsEvents_whenStopped`).
- With `timeout > 0`, every open SSE stream holds `stop` for the full timeout. Open WebSockets do
  the same today.

### The WebSocket precedent

- `HTTPResponse.Payload.webSocket(any WSHandler)` is a separate payload case, because the
  connection switches protocol.
- `MessageFrameWSHandler` bounds both directions with `AsyncHandoff(capacity: 16)` (#249).
- It runs the work in a `Task` that's cancelled from the outbound stream's `onTermination`.
- SSE needs none of the protocol switch. It's plain HTTP, so it doesn't need its own payload case.
  It does reuse the bounded `AsyncHandoff` and the "cancel the producer when the consumer goes
  away" pattern.

### Side finding: the client can't read an event stream yet

`AsyncSocket.readResponse()` (`HTTPDecoder.decodeResponse`) buffers a chunked body until it ends
(`HTTPBodySequence.get()`), so `HTTPClient` can't consume an event stream. That's out of scope here.
The prototype's tests read raw bytes instead.

---

## 3. API options

### A. `HTTPResponse(serverSentEvents:)` plus `SSEEvent` (prototyped)

```swift
server.appendRoute("GET /events") { request in
    let start = Int(request.lastEventID ?? "0") ?? 0
    return HTTPResponse(serverSentEvents: ticker.events(after: start))   // some AsyncSequence<SSEEvent>
}

public extension HTTPResponse {
    init<Events: AsyncSequence & Sendable>(
        headers: HTTPHeaders = [:],
        serverSentEvents events: Events,
        heartbeat: TimeInterval? = 15,
        capacity: Int = 16
    ) where Events.Element == SSEEvent
}
```

- Returns a normal `.httpBody` payload, so it needs no new `Payload` case. Adding a case to the
  public enum would break exhaustive `switch`es in user code.
- Works with routing, route parameters, `HTTPHeaders` and the existing timeout.
- The handler can still reject the request: `401`, or `204` to stop reconnects.
- Sets `Content-Type: text/event-stream` and `Cache-Control: no-cache` unless the caller already
  set them.
- Generic over `AsyncSequence & Sendable`, not `some AsyncSequence<SSEEvent, …>`. Primary associated
  types on `AsyncSequence` need macOS 15, and the package targets older systems.

### B. A route helper: `.serverSentEvents { request in … }`

Sugar, for example an `SSEHTTPHandler` and `appendRoute("GET /events", to: .serverSentEvents { … })`.

- It's a thin layer over A, and could pass `lastEventID` as a closure argument.
- On its own it hides the status code, making `204` and auth failures awkward.
- Worth adding later if people want it, built on A.

### C. A new `Payload.serverSentEvents` case

Only needed if the connection must behave differently for SSE, for example close-delimited framing,
or watching the read side for EOF. Neither is needed now, and adding the case is source-breaking.
Not recommended.

### D. A push-style continuation, as well as A

```swift
HTTPResponse.serverSentEvents { stream in          // stream: SSEEventContinuation
    for await update in model.updates {
        try await stream.send(SSEEvent(data: update.json))   // suspends while the buffer is full
    }
}
```

- Apps that *push* events today reach for `AsyncStream`, whose default buffer is **unbounded**.
- A continuation backed by the same `AsyncHandoff` gives push producers real backpressure. `send`
  throws once the client has gone, which tells the producer to stop.
- This is cheap to add on top of A's machinery. It's an open question whether it belongs in v1.

### How the handler sees `Last-Event-ID`

- `HTTPHeader.lastEventID` and `HTTPRequest.lastEventID: String?` (prototyped). It's just the
  header.
- Apps that also want a query-parameter fallback read `request.query["lastEventId"]` themselves.

### Encoding `SSEEvent` (prototyped)

```swift
public struct SSEEvent: Sendable, Hashable {
    public let event: String?, data: String?, id: String?, retry: Int? /* ms */, comment: String?
    public init(data: String)                                               // never throws
    public init(event:data:id:retry:) throws                                // validates
    public static func comment(_ text: String = "") -> SSEEvent
    public enum InvalidField: Error { case event, id, retry }
}
```

- **`data`** is split at CRLF, CR or LF *only*. Splitting at `Character.isNewline` would turn
  U+2028 into a line break. Each piece becomes a `data: ` line, and empty lines are kept, so
  `"a\n\nb"` round-trips exactly.
- **`event` and `id`** throw `InvalidField` if they contain CR or LF. `id` also throws if it
  contains U+0000, because the client would ignore it.
- **`retry`** must not be negative. It's written as integer milliseconds.
- **Comments** are written as `: text`, one line per line of text. An empty comment, the heartbeat,
  is a bare `:`.
- The order is comment, `event`, `id`, `retry`, then `data` lines, then a blank line. Every field is
  written as `name: value`, so leading spaces survive.
- `String` guarantees valid Unicode, so the UTF-8 output is always valid.

---

## 4. Limits and lifecycle (as prototyped)

`SSEEventBytes` is an internal `AsyncBufferedSequence<UInt8>` that is passed to the existing chunked
`HTTPBodySequence`.

- **Producer task.** Making the iterator starts a task, owned by a `Producer` class. That task reads
  the events and encodes each one into an `AsyncHandoff<[UInt8]>(capacity:)`.
- **Backpressure** comes from three places:
  1. `socket.write` suspends while the kernel send buffer is full.
  2. The handoff holds at most `capacity` encoded events, 16 by default. When it's full, the
     producer stops reading the source sequence.
  3. Pull-based sequences are therefore read only as fast as the client reads.
  - Test: `slowReader_limitsEventsRead`.
  - An `AsyncStream` with the default `.unbounded` policy still buffers *before* this point.
    Document `.bufferingNewest(n)`, or add option D.
- **Heartbeat.** A sibling task sends `:\n\n` every `heartbeat` seconds, 15 by default, `nil` to
  turn it off. It keeps proxies from timing out the connection, and it **bounds how long it takes to
  notice a disconnected client**, because the server only finds out on a write.
  - The prototype sends heartbeats at a fixed interval, not only when idle.
  - Tests: `heartbeat_isSentWhileIdle`, `server_cancelsEvents_whenClientDisconnects`.
- **Handler timeout.** Doesn't apply to the stream, as section 2 explains. No change needed.
- **Client disconnect.** A failed write ends `sendResponse` and releases the body iterator. The
  `Producer`'s `deinit` cancels its task, which cancels iteration of the source sequence. For
  `AsyncStream`, `onTermination` fires. Tests: `releasingIterator_cancelsEvents` and the server
  disconnect test.
- **`server.stop()`.** Cancellation ends the handoff, the terminating chunk is written, and the
  producer is cancelled. With `stop(timeout: t > 0)`, streams keep running until `t` passes. This is
  an open question.
- **Source errors.** If the event sequence throws, the body throws, so the response is aborted
  without the terminating chunk and the connection is closed. The client sees a broken stream and
  reconnects. This is an open question.
- **Event size.** There's no limit. Events come from the server, so the risk is lower than for
  WebSocket frames from the client. Memory per connection is about `capacity × largest event`. An
  event bigger than the suggested buffer (4096) is split across several chunks, which is still
  correct; it only means more than one write.

---

## 5. Recommendation

Adopt **option A**, as prototyped:

- `SSEEvent`, with validation and spec-exact encoding
- `HTTPResponse(serverSentEvents:heartbeat:capacity:)` over the existing chunked body path
- `HTTPHeader.lastEventID` and `HTTPRequest.lastEventID`
- a bounded `AsyncHandoff` between producer and socket, heartbeat comments on by default, and the
  producer cancelled when the body iterator is released

This needs no change to `HTTPConnection`, `HTTPServer` or the `Payload` enum.

Possible follow-ups, each its own PR:

1. Option D, a push continuation with backpressure, if apps want push.
2. Option B, a route helper, if wanted.
3. A graceful `stop()` that ends in-flight streaming bodies, and WebSockets, when stopping begins,
   instead of after the timeout.
4. `HTTPClient` support for reading streaming chunked bodies.

### Open questions for you

1. **Validation style.** `SSEEvent(data:)` never throws, and the full initialiser throws on a bad
   `event`, `id` or `retry`. Do you prefer a non-throwing init that fails the stream when the event
   is encoded, or one that sanitises the value by stripping line breaks?
2. **`retry` type.** `Int` milliseconds, as the spec has it, or `TimeInterval` to match the rest of
   the API?
3. **Heartbeat default.** On at 15 s, as now? Sent at a fixed interval, or only after 15 s without
   an event? The idle form saves bandwidth but needs a resettable timer.
4. **Source errors.** Abort the response so the client reconnects, as now, or end it cleanly?
   Either way the client reconnects, but aborting is visible in client logs and proxies.
5. **`stop()`.** Should an in-flight SSE stream end as soon as `stop()` begins, so a positive
   timeout doesn't always wait? That needs `HTTPConnection` to track the active body, and would
   apply to WebSockets too.
6. **Push API (D).** In the first PR or later?
7. **Framing.** Chunked, as now, or offer close-delimited (`Connection: close`, no
   `Transfer-Encoding`) for proxies that buffer chunked responses?
8. **Event size limit.** Add a `maxEventSize`, or rely on `capacity` and the app?
9. **Naming.** `SSEEvent` or `ServerSentEvent`? `serverSentEvents:` as the init label?
