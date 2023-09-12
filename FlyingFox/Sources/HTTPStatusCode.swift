//
//  HTTPStatusCode.swift
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

public struct HTTPStatusCode: Sendable, Hashable {
    public var code: Int
    public var phrase: String

    public init(_ code: Int, phrase: String) {
        self.code = code
        self.phrase = phrase
    }
}

public extension HTTPStatusCode {
    // The following codes and phrases are based on:
    // https://developer.mozilla.org/en-US/docs/Web/HTTP/Status
    
    // 1xx Information responses
    static let `continue`                       = HTTPStatusCode(100, phrase: "Continue")
    static let switchingProtocols               = HTTPStatusCode(101, phrase: "Switching Protocols")
    static let earlyHints                       = HTTPStatusCode(103, phrase: "Early Hints")
    
    // 2xx Successful responses
    static let ok                               = HTTPStatusCode(200, phrase: "OK")
    static let created                          = HTTPStatusCode(201, phrase: "Created")
    static let accepted                         = HTTPStatusCode(202, phrase: "Accepted")
    static let nonAuthoritativeInformation      = HTTPStatusCode(203, phrase: "Non-Authoritative Information")
    static let noContent                        = HTTPStatusCode(204, phrase: "No Content")
    static let resetContent                     = HTTPStatusCode(205, phrase: "Reset Content")
    static let partialContent                   = HTTPStatusCode(206, phrase: "Partial Content")
    
    // 3xx Redirection messages
    static let multipleChoice                   = HTTPStatusCode(300, phrase: "Multiple Choice")
    static let movedPermanently                 = HTTPStatusCode(301, phrase: "Moved Permanently")
    static let found                            = HTTPStatusCode(302, phrase: "Found")
    static let seeOther                         = HTTPStatusCode(303, phrase: "See Other")
    static let notModified                      = HTTPStatusCode(304, phrase: "Not Modified")
    static let useProxy                         = HTTPStatusCode(305, phrase: "Use Proxy")
    static let unused                           = HTTPStatusCode(306, phrase: "unused")
    static let temporaryRedirect                = HTTPStatusCode(307, phrase: "Temporary Redirect")
    static let permanentRedirect                = HTTPStatusCode(308, phrase: "Permanent Redirect")
    
    // 4xx Client error responses
    static let badRequest                       = HTTPStatusCode(400, phrase: "Bad Request")
    static let unauthorized                     = HTTPStatusCode(401, phrase: "Unauthorized")
    static let paymentRequired                  = HTTPStatusCode(402, phrase: "Payment Required")
    static let forbidden                        = HTTPStatusCode(403, phrase: "Forbidden")
    static let notFound                         = HTTPStatusCode(404, phrase: "Not Found")
    static let methodNotAllowed                 = HTTPStatusCode(405, phrase: "Method Not Allowed")
    static let notAcceptable                    = HTTPStatusCode(406, phrase: "Not Acceptable")
    static let proxyAuthenticationRequired      = HTTPStatusCode(407, phrase: "Proxy Authentication Required")
    static let requestTimeout                   = HTTPStatusCode(408, phrase: "Request Timeout")
    static let conflict                         = HTTPStatusCode(409, phrase: "Conflict")
    static let gone                             = HTTPStatusCode(410, phrase: "Gone")
    static let lengthRequired                   = HTTPStatusCode(411, phrase: "Length Required")
    static let preconditionFailed               = HTTPStatusCode(412, phrase: "Precondition Failed")
    static let payloadTooLarge                  = HTTPStatusCode(413, phrase: "Payload Too Large")
    static let uriTooLong                       = HTTPStatusCode(414, phrase: "URI Too Long")
    static let unsupportedMediaType             = HTTPStatusCode(415, phrase: "Unsupported Media Type")
    static let rangeNotSatisfiable              = HTTPStatusCode(416, phrase: "Range Not Satisfiable")
    static let expectationFailed                = HTTPStatusCode(417, phrase: "Expectation Failed")
    static let teapot                           = HTTPStatusCode(418, phrase: "I'm a teapot")
    static let misdirectedRequest               = HTTPStatusCode(421, phrase: "Misdirected Request")
    static let unprocessableContent             = HTTPStatusCode(422, phrase: "Unprocessable Content")
    static let locked                           = HTTPStatusCode(423, phrase: "Locked")
    static let failedDependency                 = HTTPStatusCode(424, phrase: "Failed Dependency")
    static let tooEarly                         = HTTPStatusCode(425, phrase: "Too Early")
    static let upgradeRequired                  = HTTPStatusCode(426, phrase: "Upgrade Required")
    static let preconditionRequired             = HTTPStatusCode(428, phrase: "Precondition Required")
    static let tooManyRequests                  = HTTPStatusCode(429, phrase: "Too Many Requests")
    static let requestHeaderFieldsTooLarge      = HTTPStatusCode(431, phrase: "Request Header Fields Too Large")
    static let unavailableForLegalReasons       = HTTPStatusCode(451, phrase: "Unavailable For Legal Reasons")
    
    // 5xx Server error responses
    static let internalServerError              = HTTPStatusCode(500, phrase: "Internal Server Error")
    static let notImplemented                   = HTTPStatusCode(501, phrase: "Not Implemented")
    static let badGateway                       = HTTPStatusCode(502, phrase: "Bad Gateway")
    static let serviceUnavailable               = HTTPStatusCode(503, phrase: "Service Unavailable")
    static let gatewayTimeout                   = HTTPStatusCode(504, phrase: "Gateway Timeout")
    static let httpVersionNotSupported          = HTTPStatusCode(505, phrase: "HTTP Version Not Supported")
    static let variantAlsoNegotiates            = HTTPStatusCode(506, phrase: "Variant Also Negotiates")
    static let notExtended                      = HTTPStatusCode(510, phrase: "Not Extended")
    static let networkAuthenticationRequired    = HTTPStatusCode(511, phrase: "Network Authentication Required")
}
