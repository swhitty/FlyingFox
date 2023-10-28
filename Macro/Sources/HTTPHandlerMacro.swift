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
            guard let funcSyntax = member.decl.as(FunctionDeclSyntax.self) else {
                return nil
            }

            let funcDecl = FunctionDecl.make(from: funcSyntax)
            guard let routeAtt = funcDecl.attribute(name: "HTTPRoute") else {
                return nil
            }

            guard let firstLabel = routeAtt.labelExpressions.first else {
                return nil
            }

            return RouteDecl(
                route: firstLabel.expression,
                statusCode: routeAtt.expression(name: "statusCode")?.expression ?? ".ok",
                funcDecl: funcDecl
            )
        }

        var validRoutes = Set<String>()
        for route in routes {
            guard !validRoutes.contains(route.route) else {
                throw CustomError.message(
                    "@HTTPRoute(\"\(route.route)\") is ambiguous"
                )
            }
            validRoutes.insert(route.route)
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
        var funcDecl: FunctionDecl

        var routeSyntax: String {
            if funcDecl.returnType.isVoid {
                return """
                if await HTTPRoute("\(route)") ~= request { \(funcCallSyntax)
                return HTTPResponse(statusCode: \(statusCode))
                }
                """
            } else {
                return """
                if await HTTPRoute("\(route)") ~= request { return \(funcCallSyntax) }
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
            call += funcDecl.name
            if let param = funcDecl.parameters.first {
                if let label = param.label {
                    call += "(" + label + ": request)"
                } else {
                    call += "(request)"
                }
            } else {
                call += "()"
            }
            return call
        }
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
