//
//  JSONRouteMacro.swift
//  FlyingFox
//
//  Created by Simon Whitty on 29/10/2023.
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
import SwiftDiagnostics

public struct JSONRouteMacro: PeerMacro {
    public static func expansion<
        Context: MacroExpansionContext,
        Declaration: DeclSyntaxProtocol
    >(
        of node: AttributeSyntax,
        providingPeersOf declaration: Declaration,
        in context: Context
    ) throws -> [DeclSyntax] {

        // Only func can be a route
        guard let funcSyntax = declaration.as(FunctionDeclSyntax.self) else {
            throw CustomError.message("@JSONRoute can only be attached to functions")
        }

        let funcDecl = FunctionDecl.make(from: funcSyntax)
        let routeAtt = funcDecl.attribute(name: "JSONRoute")!

        switch funcDecl.parameters.count {
        case 2:
            guard funcDecl.parameters[0].type.isHTTPRequest else {
                throw CustomError.message(
                    "@JSONRoute requires the first parameter is HTTPRequest"
                )
            }
        case 1, 0:
            ()
        default:
            throw CustomError.message(
                "@JSONRoute requires a function that accepts 1 paramerter"
            )
        }

        if routeAtt.expression(name: "decoder") != nil &&
           !funcDecl.parameters.contains(where: { !$0.type.isHTTPRequest }) {
            context.diagnoseWarning(for: node, "decoder is unused")
        }

        if routeAtt.expression(name: "encoder") != nil &&
                (funcDecl.returnType.isHTTPResponse || funcDecl.returnType.isVoid) {
            context.diagnoseWarning(for: node, "encoder is unused for return type")
        }

        // Does nothing, used only to decorate functions with data
        return []
    }
}
