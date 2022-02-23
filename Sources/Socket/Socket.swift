//
//  Socket.swift
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

struct Socket: Sendable, Hashable {

    let file: Int32

    init(file: Int32) {
        self.file = file
    }

    init(domain: Int32, type: Int32) throws {
        self.file = Socket.socket(domain, type, 0)
        if file == -1 {
            throw SocketError.makeFailed("CreateSocket")
        }
    }

    var flags: Flags {
        Flags(rawValue: Socket.fcntl(file, F_GETFL))
    }

    func setFlags(_ flags: Flags) throws {
        if Socket.fcntl(file, F_SETFL, flags.rawValue) == -1 {
            throw SocketError.makeFailed("SetFlags")
        }
    }

    func setValue<O: SocketOption>(_ value: O.Value, for option: O) throws {
        var value = option.makeSocketValue(from: value)
        let length = socklen_t(MemoryLayout<O.SocketValue>.size)
        guard Socket.setsockopt(file, SOL_SOCKET, option.name, &value, length) >= 0 else {
            throw SocketError.makeFailed("SetOption")
        }
    }

    func getValue<O: SocketOption>(for option: O) throws -> O.Value {
        let valuePtr = UnsafeMutablePointer<O.SocketValue>.allocate(capacity: 1)
        var length = socklen_t(MemoryLayout<O.SocketValue>.size)
        guard Socket.getsockopt(file, SOL_SOCKET, option.name, valuePtr, &length) >= 0 else {
            throw SocketError.makeFailed("GetOption")
        }
        return option.makeValue(from: valuePtr.pointee)
    }

    func bindIP6(port: UInt16, listenAddress: String? = nil) throws {
        var addr = Socket.sockaddr_in6(port: port)

        if let address = listenAddress {
            guard address.withCString({ cstring in inet_pton(AF_INET6, cstring, &addr.sin6_addr) }) == 1 else {
                throw SocketError.makeFailed("BindAddr")
            }
        }

        let result = withUnsafePointer(to: &addr) {
            Socket.bind(file, UnsafePointer<sockaddr>(OpaquePointer($0)), socklen_t(MemoryLayout<sockaddr_in6>.size))
        }

        if result == -1 {
            let error = SocketError.makeFailed("Bind")
            try close()
            throw error
        }
    }

    func listen(maxPendingConnection: Int32 = SOMAXCONN) throws {
        if Socket.listen(file, maxPendingConnection) == -1 {
            let error = SocketError.makeFailed("Listen")
            try close()
            throw error
        }
    }

    func remoteHostname() throws -> String {
        var addr = sockaddr()
        var len = socklen_t(MemoryLayout<sockaddr>.size)
        if Socket.getpeername(file, &addr, &len) != 0 {
            throw SocketError.makeFailed("GetPeerName")
        }
        let capacity = Int(NI_MAXHOST)
        let hostBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: capacity)
        if Socket.getnameinfo(&addr, len, hostBuffer, socklen_t(capacity), nil, 0, NI_NUMERICHOST) != 0 {
            throw SocketError.makeFailed("GetNameInfo")
        }
        return String(cString: hostBuffer)
    }

    func accept() throws -> (file: Int32, addr: sockaddr) {
        var addr = sockaddr()
        var len: socklen_t = 0
        let newFile = Socket.accept(file, &addr, &len)

        if newFile == -1 {
            if errno == EWOULDBLOCK {
                throw SocketError.blocked
            } else {
                throw SocketError.makeFailed("Accept")
            }
        }

        return (newFile, addr)
    }

    func read() throws -> UInt8 {
        var byte: UInt8 = 0
        _ = try withUnsafeMutablePointer(to: &byte) { buffer in
            try read(into: buffer, length: 1)
        }
        return byte
    }

    func read(atMost length: Int) throws -> [UInt8] {
        try [UInt8](unsafeUninitializedCapacity: length) { buffer, count in
            guard let baseAddress = buffer.baseAddress else {
                throw SocketError.makeFailed("Read Buffer")
            }
            count = try read(into: baseAddress, length: length)
        }
    }

    private func read(into buffer: UnsafeMutablePointer<UInt8>, length: Int) throws -> Int {
        let count = Socket.read(file, buffer, length)
        if count > 0 {
            return count
        } else if errno == EWOULDBLOCK {
            throw SocketError.blocked
        } else if errno == EBADF || count == 0 {
            throw SocketError.disconnected
        } else {
            throw SocketError.makeFailed("Read")
        }
    }

    func write(_ data: Data, from index: Data.Index) throws -> Data.Index {
        guard index < data.endIndex else { return data.endIndex }
        return try data.withUnsafeBytes {
            guard let baseAddress = $0.baseAddress else {
                throw SocketError.makeFailed("WriteBuffer")
            }
            let sent = try write(baseAddress + index, length: data.endIndex - index)
            return index + sent
        }
    }

    private func write(_ pointer: UnsafeRawPointer, length: Int) throws -> Int {
        let sent = Socket.write(file, pointer, length)
        guard sent > 0 else {
            if errno == EWOULDBLOCK {
                throw SocketError.blocked
            } else if errno == EBADF {
                throw SocketError.disconnected
            } else {
                throw SocketError.makeFailed("Write")
            }
        }
        return sent
    }

    func close() throws {
        if Socket.close(file) == -1 {
            if errno == EWOULDBLOCK {
                throw SocketError.blocked
            } else {
                throw SocketError.makeFailed("Close")
            }
        }
    }
}

extension Socket {
    struct Flags: OptionSet {
        var rawValue: Int32

        static let nonBlocking = Flags(rawValue: O_NONBLOCK)
    }
}

protocol SocketOption {
    associatedtype Value
    associatedtype SocketValue

    var name: Int32 { get }
    func makeValue(from socketValue: SocketValue) -> Value
    func makeSocketValue(from value: Value) -> SocketValue
}

struct BoolSocketOption: SocketOption {
    var name: Int32

    func makeValue(from socketValue: Int32) -> Bool {
        socketValue > 0
    }

    func makeSocketValue(from value: Bool) -> Int32 {
        value ? 1 : 0
    }
}

struct Int32SocketOption: SocketOption {
    var name: Int32

    func makeValue(from socketValue: Int32) -> Int32 {
        socketValue
    }

    func makeSocketValue(from value: Int32) -> Int32 {
        value
    }
}

extension SocketOption where Self == BoolSocketOption {
    static var localAddressReuse: Self {
        BoolSocketOption(name: SO_REUSEADDR)
    }

    #if canImport(Darwin)
    // Prevents SIG_TRAP when app is paused / running in background.
    static var noSIGPIPE: Self {
        BoolSocketOption(name: SO_NOSIGPIPE)
    }
    #endif
}

extension SocketOption where Self == Int32SocketOption {
    static var sendBufferSize: Self {
        Int32SocketOption(name: SO_SNDBUF)
    }

    static var receiveBufferSize: Self {
        Int32SocketOption(name: SO_RCVBUF)
    }
}
