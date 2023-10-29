//
//  HTTPHandlerMacro.swift
//  FlyingFox
//
//  Created by Simon Whitty on 26/10/2023.
//  Copyright © 2023 Simon Whitty. All rights reserved.
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

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum HTTPHandlerMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let memberList = declaration.memberBlock.members

        let routes = memberList.compactMap { member -> RouteDecl? in
            guard let funcDecl = FunctionDecl.make(from: member),
                  let routeAtt = funcDecl.attribute(name: "HTTPRoute") ?? funcDecl.attribute(name: "JSONRoute") else {
                return nil
            }

            let isJSON = routeAtt.name == "JSONRoute"
            let defaultHeaders = isJSON ? #"[.contentType: "application/json"]"# : "[:]"

            return RouteDecl(
                route: routeAtt.labelExpressions[0].expression,
                statusCode: routeAtt.expression(name: "statusCode")?.expression ?? ".ok",
                headers: routeAtt.expression(name: "headers")?.expression ?? defaultHeaders,
                funcDecl: funcDecl,
                isJSON: isJSON,
                encoder: routeAtt.expression(name: "encoder")?.expression ?? "JSONEncoder()",
                decoder: routeAtt.expression(name: "decoder")?.expression ?? "JSONDecoder()"
            )
        }

        if routes.isEmpty {
            context.diagnoseWarning(for: node, "No HTTPRoute found")
        }

        let routeDecl: DeclSyntax = """
        func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
            \(raw: routes.map(\.routeSyntax).joined(separator: "\n"))
            throw HTTPUnhandledError()
        }
        """

        //

        return [
            routeDecl
        ]
    }
}

extension HTTPHandlerMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        [try ExtensionDeclSyntax("extension \(type.trimmed): HTTPHandler {}")]
    }
}

private extension HTTPHandlerMacro {
    struct RouteDecl {
        var route: String
        var statusCode: String
        var headers: String
        var funcDecl: FunctionDecl
        var isJSON: Bool
        var encoder: String
        var decoder: String

        var routeSyntax: String {
            if isJSON {
                jsonRouteSyntax
            } else {
                httpRouteSyntax
            }
        }

        var httpRouteSyntax: String {
            if funcDecl.returnType.isVoid {
                """
                if await HTTPRoute("\(route)") ~= request { \(funcCallSyntax)
                return HTTPResponse(statusCode: \(statusCode), headers: \(headers))
                }
                """
            } else {
                """
                if await HTTPRoute("\(route)") ~= request { return \(funcCallSyntax) }
                """
            }
        }

        var jsonBodyDecodeSyntax: String {
            guard let bodyParam = funcDecl.parameters.first(where: { !$0.type.isHTTPRequest }) else {
                return ""
            }
            return """
            let body = try await \(decoder).decode(\(bodyParam.type).self, from: request.bodyData)
            """
        }

        var jsonRouteSyntax: String {
            if funcDecl.returnType.isVoid {
                """
                if await HTTPRoute("\(route)") ~= request {
                \(jsonBodyDecodeSyntax)\(funcCallSyntax)
                return HTTPResponse(statusCode: \(statusCode), headers: \(headers))
                }
                """
            } else {
                """
                if await HTTPRoute("\(route)") ~= request {
                \(jsonBodyDecodeSyntax)
                let ret = \(funcCallSyntax)
                return try HTTPResponse(
                    statusCode: \(statusCode),
                    headers: \(headers),
                    body: \(encoder).encode(ret)
                )
                }
                """
            }
        }

        var funcCallSyntax: String {
            var call = ""
            if funcDecl.effects.contains(.throws) {
                call += "try "
            }
            if funcDecl.effects.contains(.async) {
                call += "await "
            }
            call += funcDecl.name + "("
            call += funcDecl.parameters
                .map(\.funcCallSyntax)
                .joined(separator: ", ")

            call += ")"
            return call
        }
    }
}

extension FunctionDecl.Parameter {

    var funcCallSyntax: String {
        let variable = type.isHTTPRequest ? "request" : "body"
        return [label, variable]
            .compactMap { $0 }
            .joined(separator: ": ")
    }
}

extension StringLiteralExprSyntax {

    func singleStringSegment() throws -> String {
        guard segments.count == 1,
              case let .stringSegment(segment)? = segments.first else {
            throw CustomError.message(
                "invalid String Literal"
            )
        }
        return segment.content.text
    }
}
