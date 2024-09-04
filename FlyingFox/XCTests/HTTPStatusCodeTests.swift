//
//  HTTPStatusCodeTests.swift
//  FlyingFox
//
//  Created by Andre Jacobs on 17/02/2022.
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

import XCTest
import FlyingFox

final class HTTPStatusCodeTests: XCTestCase {

    func test1xxStatusCodes() throws {
        XCTAssertEqual(HTTPStatusCode.continue, HTTPStatusCode(100, phrase: "Continue"))
        XCTAssertEqual(HTTPStatusCode.switchingProtocols, HTTPStatusCode(101, phrase: "Switching Protocols"))
        XCTAssertEqual(HTTPStatusCode.earlyHints, HTTPStatusCode(103, phrase: "Early Hints"))
    }

    func test2xxStatusCodes() throws {
        XCTAssertEqual(HTTPStatusCode.ok, HTTPStatusCode(200, phrase: "OK"))
        XCTAssertEqual(HTTPStatusCode.created, HTTPStatusCode(201, phrase: "Created"))
        XCTAssertEqual(HTTPStatusCode.accepted, HTTPStatusCode(202, phrase: "Accepted"))
        XCTAssertEqual(HTTPStatusCode.nonAuthoritativeInformation, HTTPStatusCode(203, phrase: "Non-Authoritative Information"))
        XCTAssertEqual(HTTPStatusCode.noContent, HTTPStatusCode(204, phrase: "No Content"))
        XCTAssertEqual(HTTPStatusCode.resetContent, HTTPStatusCode(205, phrase: "Reset Content"))
        XCTAssertEqual(HTTPStatusCode.partialContent, HTTPStatusCode(206, phrase: "Partial Content"))
    }

    func test3xxStatusCodes() throws {
        XCTAssertEqual(HTTPStatusCode.multipleChoice, HTTPStatusCode(300, phrase: "Multiple Choice"))
        XCTAssertEqual(HTTPStatusCode.movedPermanently, HTTPStatusCode(301, phrase: "Moved Permanently"))
        XCTAssertEqual(HTTPStatusCode.found, HTTPStatusCode(302, phrase: "Found"))
        XCTAssertEqual(HTTPStatusCode.seeOther, HTTPStatusCode(303, phrase: "See Other"))
        XCTAssertEqual(HTTPStatusCode.notModified, HTTPStatusCode(304, phrase: "Not Modified"))
        XCTAssertEqual(HTTPStatusCode.useProxy, HTTPStatusCode(305, phrase: "Use Proxy"))
        XCTAssertEqual(HTTPStatusCode.unused, HTTPStatusCode(306, phrase: "unused"))
        XCTAssertEqual(HTTPStatusCode.temporaryRedirect, HTTPStatusCode(307, phrase: "Temporary Redirect"))
        XCTAssertEqual(HTTPStatusCode.permanentRedirect, HTTPStatusCode(308, phrase: "Permanent Redirect"))
    }

    func test4xxStatusCodes() throws {
        XCTAssertEqual(HTTPStatusCode.badRequest, HTTPStatusCode(400, phrase: "Bad Request"))
        XCTAssertEqual(HTTPStatusCode.unauthorized, HTTPStatusCode(401, phrase: "Unauthorized"))
        XCTAssertEqual(HTTPStatusCode.paymentRequired, HTTPStatusCode(402, phrase: "Payment Required"))
        XCTAssertEqual(HTTPStatusCode.forbidden, HTTPStatusCode(403, phrase: "Forbidden"))
        XCTAssertEqual(HTTPStatusCode.notFound, HTTPStatusCode(404, phrase: "Not Found"))
        XCTAssertEqual(HTTPStatusCode.methodNotAllowed, HTTPStatusCode(405, phrase: "Method Not Allowed"))
        XCTAssertEqual(HTTPStatusCode.notAcceptable, HTTPStatusCode(406, phrase: "Not Acceptable"))
        XCTAssertEqual(HTTPStatusCode.proxyAuthenticationRequired, HTTPStatusCode(407, phrase: "Proxy Authentication Required"))
        XCTAssertEqual(HTTPStatusCode.requestTimeout, HTTPStatusCode(408, phrase: "Request Timeout"))
        XCTAssertEqual(HTTPStatusCode.conflict, HTTPStatusCode(409, phrase: "Conflict"))
        XCTAssertEqual(HTTPStatusCode.gone, HTTPStatusCode(410, phrase: "Gone"))
        XCTAssertEqual(HTTPStatusCode.lengthRequired, HTTPStatusCode(411, phrase: "Length Required"))
        XCTAssertEqual(HTTPStatusCode.preconditionFailed, HTTPStatusCode(412, phrase: "Precondition Failed"))
        XCTAssertEqual(HTTPStatusCode.payloadTooLarge, HTTPStatusCode(413, phrase: "Payload Too Large"))
        XCTAssertEqual(HTTPStatusCode.uriTooLong, HTTPStatusCode(414, phrase: "URI Too Long"))
        XCTAssertEqual(HTTPStatusCode.unsupportedMediaType, HTTPStatusCode(415, phrase: "Unsupported Media Type"))
        XCTAssertEqual(HTTPStatusCode.rangeNotSatisfiable, HTTPStatusCode(416, phrase: "Range Not Satisfiable"))
        XCTAssertEqual(HTTPStatusCode.expectationFailed, HTTPStatusCode(417, phrase: "Expectation Failed"))
        XCTAssertEqual(HTTPStatusCode.teapot, HTTPStatusCode(418, phrase: "I'm a teapot"))
        XCTAssertEqual(HTTPStatusCode.misdirectedRequest, HTTPStatusCode(421, phrase: "Misdirected Request"))
        XCTAssertEqual(HTTPStatusCode.unprocessableContent, HTTPStatusCode(422, phrase: "Unprocessable Content"))
        XCTAssertEqual(HTTPStatusCode.locked, HTTPStatusCode(423, phrase: "Locked"))
        XCTAssertEqual(HTTPStatusCode.failedDependency, HTTPStatusCode(424, phrase: "Failed Dependency"))
        XCTAssertEqual(HTTPStatusCode.tooEarly, HTTPStatusCode(425, phrase: "Too Early"))
        XCTAssertEqual(HTTPStatusCode.upgradeRequired, HTTPStatusCode(426, phrase: "Upgrade Required"))
        XCTAssertEqual(HTTPStatusCode.preconditionRequired, HTTPStatusCode(428, phrase: "Precondition Required"))
        XCTAssertEqual(HTTPStatusCode.tooManyRequests, HTTPStatusCode(429, phrase: "Too Many Requests"))
        XCTAssertEqual(HTTPStatusCode.requestHeaderFieldsTooLarge, HTTPStatusCode(431, phrase: "Request Header Fields Too Large"))
        XCTAssertEqual(HTTPStatusCode.unavailableForLegalReasons, HTTPStatusCode(451, phrase: "Unavailable For Legal Reasons"))
    }

    func test5xxStatusCodes() throws {
        XCTAssertEqual(HTTPStatusCode.internalServerError, HTTPStatusCode(500, phrase: "Internal Server Error"))
        XCTAssertEqual(HTTPStatusCode.notImplemented, HTTPStatusCode(501, phrase: "Not Implemented"))
        XCTAssertEqual(HTTPStatusCode.badGateway, HTTPStatusCode(502, phrase: "Bad Gateway"))
        XCTAssertEqual(HTTPStatusCode.serviceUnavailable, HTTPStatusCode(503, phrase: "Service Unavailable"))
        XCTAssertEqual(HTTPStatusCode.gatewayTimeout, HTTPStatusCode(504, phrase: "Gateway Timeout"))
        XCTAssertEqual(HTTPStatusCode.httpVersionNotSupported, HTTPStatusCode(505, phrase: "HTTP Version Not Supported"))
        XCTAssertEqual(HTTPStatusCode.variantAlsoNegotiates, HTTPStatusCode(506, phrase: "Variant Also Negotiates"))
        XCTAssertEqual(HTTPStatusCode.notExtended, HTTPStatusCode(510, phrase: "Not Extended"))
        XCTAssertEqual(HTTPStatusCode.networkAuthenticationRequired, HTTPStatusCode(511, phrase: "Network Authentication Required"))
    }

}
