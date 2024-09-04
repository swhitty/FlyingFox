//
//  HTTPLoggingTests.swift
//  FlyingFox
//
//  Created by Simon Whitty on 23/02/2022.
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
import Testing

struct HTTPLoggingTests {

    @Test
    func printLogger_DefaultCategory() {
        let logger = PrintLogger.print()

        #expect(
            logger.category == "FlyingFox"
        )
    }

    @Test
    func listeningLog_INETPort() {
        #expect(
            PrintLogger.makeListening(on: .ip4("0.0.0.0", port: 1234)) == "starting server port: 1234"
        )
    }

    @Test
    func listeningLog_INET() throws {
        #expect(
            PrintLogger.makeListening(on: .ip4("8.8.8.8", port: 1234)) == "starting server 8.8.8.8:1234"
        )
    }

    @Test
    func listeningLog_INET6Port() {
        #expect(
            PrintLogger.makeListening(on: .ip6("::", port: 5678)) == "starting server port: 5678"
        )
    }

    @Test
    func listeningLog_INET6() throws {
        #expect(
            PrintLogger.makeListening(on: .ip6("::1", port: 1234)) == "starting server ::1:1234"
        )
    }

    @Test
    func listeningLog_UnixPath() {
        #expect(
            PrintLogger.makeListening(on: .unix("/var/fox/xyz")) == "starting server path: /var/fox/xyz"
        )
    }

    @Test
    func listeningLog_Invalid() {
        #expect(
            PrintLogger.makeListening(on: nil) == "starting server"
        )
    }

    @Test
    func disabledLogger_DoesNotExecuteDebugClosure() {
        let logger = DisabledLogger()
        let didLog = AllocatedLock(initialState: false)

        logger.logDebug({
            didLog.withLock { $0 = true }
            return "disabled"
        }())

        #expect(didLog.copy() == false)
    }

    @Test
    func disabledLogger_DoesNotExecuteInfoClosure() {
        let logger = DisabledLogger()
        let didLog = AllocatedLock(initialState: false)

        logger.logInfo({
            didLog.withLock { $0 = true }
            return "disabled"
        }())

        #expect(didLog.copy() == false)
    }

    @Test
    func disabledLogger_DoesNotExecuteWarningClosure() {
        let logger = DisabledLogger()
        let didLog = AllocatedLock(initialState: false)

        logger.logWarning({
            didLog.withLock { $0 = true }
            return "disabled"
        }())

        #expect(didLog.copy() == false)
    }

    @Test
    func disabledLogger_DoesNotExecuteErrorClosure() {
        let logger = DisabledLogger()
        let didLog = AllocatedLock(initialState: false)

        logger.logError({
            didLog.withLock { $0 = true }
            return "disabled"
        }())

        #expect(didLog.copy() == false)
    }

    @Test
    func disabledLogger_DoesNotExecuteCriticalClosure() {
        let logger = DisabledLogger()
        let didLog = AllocatedLock(initialState: false)

        logger.logCritical({
            didLog.withLock { $0 = true }
            return "disabled"
        }())

        #expect(didLog.copy() == false)
    }
}
