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

import FlyingFox
import Testing

struct HTTPStatusCodeTests {

    @Test
    func statusCodes1xx() throws {
        #expect(HTTPStatusCode.continue == HTTPStatusCode(100, phrase: "Continue"))
        #expect(HTTPStatusCode.switchingProtocols == HTTPStatusCode(101, phrase: "Switching Protocols"))
        #expect(HTTPStatusCode.earlyHints == HTTPStatusCode(103, phrase: "Early Hints"))
    }

    @Test
    func statusCodes2xx() throws {
        #expect(HTTPStatusCode.ok == HTTPStatusCode(200, phrase: "OK"))
        #expect(HTTPStatusCode.created == HTTPStatusCode(201, phrase: "Created"))
        #expect(HTTPStatusCode.accepted == HTTPStatusCode(202, phrase: "Accepted"))
        #expect(HTTPStatusCode.nonAuthoritativeInformation == HTTPStatusCode(203, phrase: "Non-Authoritative Information"))
        #expect(HTTPStatusCode.noContent == HTTPStatusCode(204, phrase: "No Content"))
        #expect(HTTPStatusCode.resetContent == HTTPStatusCode(205, phrase: "Reset Content"))
        #expect(HTTPStatusCode.partialContent == HTTPStatusCode(206, phrase: "Partial Content"))
    }

    @Test
    func statusCodes3xx() throws {
        #expect(HTTPStatusCode.multipleChoice == HTTPStatusCode(300, phrase: "Multiple Choice"))
        #expect(HTTPStatusCode.movedPermanently == HTTPStatusCode(301, phrase: "Moved Permanently"))
        #expect(HTTPStatusCode.found == HTTPStatusCode(302, phrase: "Found"))
        #expect(HTTPStatusCode.seeOther == HTTPStatusCode(303, phrase: "See Other"))
        #expect(HTTPStatusCode.notModified == HTTPStatusCode(304, phrase: "Not Modified"))
        #expect(HTTPStatusCode.useProxy == HTTPStatusCode(305, phrase: "Use Proxy"))
        #expect(HTTPStatusCode.unused == HTTPStatusCode(306, phrase: "unused"))
        #expect(HTTPStatusCode.temporaryRedirect == HTTPStatusCode(307, phrase: "Temporary Redirect"))
        #expect(HTTPStatusCode.permanentRedirect == HTTPStatusCode(308, phrase: "Permanent Redirect"))
    }

    @Test
    func statusCodes4xx() throws {
        #expect(HTTPStatusCode.badRequest == HTTPStatusCode(400, phrase: "Bad Request"))
        #expect(HTTPStatusCode.unauthorized == HTTPStatusCode(401, phrase: "Unauthorized"))
        #expect(HTTPStatusCode.paymentRequired == HTTPStatusCode(402, phrase: "Payment Required"))
        #expect(HTTPStatusCode.forbidden == HTTPStatusCode(403, phrase: "Forbidden"))
        #expect(HTTPStatusCode.notFound == HTTPStatusCode(404, phrase: "Not Found"))
        #expect(HTTPStatusCode.methodNotAllowed == HTTPStatusCode(405, phrase: "Method Not Allowed"))
        #expect(HTTPStatusCode.notAcceptable == HTTPStatusCode(406, phrase: "Not Acceptable"))
        #expect(HTTPStatusCode.proxyAuthenticationRequired == HTTPStatusCode(407, phrase: "Proxy Authentication Required"))
        #expect(HTTPStatusCode.requestTimeout == HTTPStatusCode(408, phrase: "Request Timeout"))
        #expect(HTTPStatusCode.conflict == HTTPStatusCode(409, phrase: "Conflict"))
        #expect(HTTPStatusCode.gone == HTTPStatusCode(410, phrase: "Gone"))
        #expect(HTTPStatusCode.lengthRequired == HTTPStatusCode(411, phrase: "Length Required"))
        #expect(HTTPStatusCode.preconditionFailed == HTTPStatusCode(412, phrase: "Precondition Failed"))
        #expect(HTTPStatusCode.payloadTooLarge == HTTPStatusCode(413, phrase: "Payload Too Large"))
        #expect(HTTPStatusCode.uriTooLong == HTTPStatusCode(414, phrase: "URI Too Long"))
        #expect(HTTPStatusCode.unsupportedMediaType == HTTPStatusCode(415, phrase: "Unsupported Media Type"))
        #expect(HTTPStatusCode.rangeNotSatisfiable == HTTPStatusCode(416, phrase: "Range Not Satisfiable"))
        #expect(HTTPStatusCode.expectationFailed == HTTPStatusCode(417, phrase: "Expectation Failed"))
        #expect(HTTPStatusCode.teapot == HTTPStatusCode(418, phrase: "I'm a teapot"))
        #expect(HTTPStatusCode.misdirectedRequest == HTTPStatusCode(421, phrase: "Misdirected Request"))
        #expect(HTTPStatusCode.unprocessableContent == HTTPStatusCode(422, phrase: "Unprocessable Content"))
        #expect(HTTPStatusCode.locked == HTTPStatusCode(423, phrase: "Locked"))
        #expect(HTTPStatusCode.failedDependency == HTTPStatusCode(424, phrase: "Failed Dependency"))
        #expect(HTTPStatusCode.tooEarly == HTTPStatusCode(425, phrase: "Too Early"))
        #expect(HTTPStatusCode.upgradeRequired == HTTPStatusCode(426, phrase: "Upgrade Required"))
        #expect(HTTPStatusCode.preconditionRequired == HTTPStatusCode(428, phrase: "Precondition Required"))
        #expect(HTTPStatusCode.tooManyRequests == HTTPStatusCode(429, phrase: "Too Many Requests"))
        #expect(HTTPStatusCode.requestHeaderFieldsTooLarge == HTTPStatusCode(431, phrase: "Request Header Fields Too Large"))
        #expect(HTTPStatusCode.unavailableForLegalReasons == HTTPStatusCode(451, phrase: "Unavailable For Legal Reasons"))
    }

    @Test
    func statusCodes5xx() throws {
        #expect(HTTPStatusCode.internalServerError == HTTPStatusCode(500, phrase: "Internal Server Error"))
        #expect(HTTPStatusCode.notImplemented == HTTPStatusCode(501, phrase: "Not Implemented"))
        #expect(HTTPStatusCode.badGateway == HTTPStatusCode(502, phrase: "Bad Gateway"))
        #expect(HTTPStatusCode.serviceUnavailable == HTTPStatusCode(503, phrase: "Service Unavailable"))
        #expect(HTTPStatusCode.gatewayTimeout == HTTPStatusCode(504, phrase: "Gateway Timeout"))
        #expect(HTTPStatusCode.httpVersionNotSupported == HTTPStatusCode(505, phrase: "HTTP Version Not Supported"))
        #expect(HTTPStatusCode.variantAlsoNegotiates == HTTPStatusCode(506, phrase: "Variant Also Negotiates"))
        #expect(HTTPStatusCode.notExtended == HTTPStatusCode(510, phrase: "Not Extended"))
        #expect(HTTPStatusCode.networkAuthenticationRequired == HTTPStatusCode(511, phrase: "Network Authentication Required"))
    }

}
