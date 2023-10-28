//
//  FunctionDecl.swift
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

struct FunctionDecl {
    var name: String
    var parameters: [Parameter]
    var effects: Effects
    var attributes: [Attribute]
    var returnType: ReturnType

    struct Parameter {
        var label: String?
        var name: String
        var type: String
    }

    struct Attribute {
        var name: String
        var labelExpressions: [LabelExpression]

        struct LabelExpression {
            var name: String?
            var expression: String
        }

        func expression(name: String) -> LabelExpression? {
            labelExpressions.first { $0.name == name }
        }
    }

    enum ReturnType {
        case void
        case type(String)
    }

    struct Effects: OptionSet {
        var rawValue: Int = 0

        static let async = Effects(rawValue: 1 << 1)
        static let `throws` = Effects(rawValue: 1 << 2)
    }

    func attribute(name: String) -> Attribute? {
        attributes.first { $0.name == name }
    }
}


extension FunctionDecl {

    static func make(from syntax: FunctionDeclSyntax) -> Self {
        var decl = FunctionDecl(
            name: syntax.name.text,
            parameters: [],
            effects: [],
            attributes: [],
            returnType: .init(syntax.signature.returnClause?.type.as(IdentifierTypeSyntax.self)?.name.text)
        )

        decl.attributes = syntax.attributes
            .compactMap {
                $0.as(AttributeSyntax.self)
            }
            .compactMap(Attribute.make)

        decl.parameters = syntax.signature
            .parameterClause
            .parameters
            .compactMap { param in
                guard let typeID = param.type.as(IdentifierTypeSyntax.self) else { return nil }
                return FunctionDecl.Parameter(
                    label: param.firstName.text == "_" ? nil : param.firstName.text,
                    name: param.secondName?.text ?? param.firstName.text,
                    type: typeID.name.text
                )
            }

        if syntax.signature.effectSpecifiers?.asyncSpecifier != nil {
            decl.effects.insert(.async)
        }

        if syntax.signature.effectSpecifiers?.throwsSpecifier != nil {
            decl.effects.insert(.throws)
        }

        return decl
    }
}

extension FunctionDecl.Attribute {

    static func make(from syntax: AttributeSyntax) -> Self? {
        guard let name = syntax.attributeName.as(IdentifierTypeSyntax.self)?.name.text else {
            return nil
        }

        var decl = FunctionDecl.Attribute (
            name: name,
            labelExpressions: []
        )

        guard let labelSyntax = syntax.arguments?.as(LabeledExprListSyntax.self) else {
            return decl
        }

        decl.labelExpressions = labelSyntax
            .map(LabelExpression.make)

        return decl
    }
}

extension FunctionDecl.Attribute.LabelExpression {

    static func make(from syntax: LabeledExprSyntax) -> Self {
        let name = syntax.label?.text
        let expression = try? syntax.expression
            .as(StringLiteralExprSyntax.self)?
            .singleStringSegment()

        return Self(
            name: name == "_" ? nil : name,
            expression: expression ?? String(describing: syntax.expression)
        )
    }
}

extension FunctionDecl.ReturnType: Equatable {

    init(_ value: String?) {
        switch value {
        case .none, "()", "Void":
            self = .void
        case .some(let string):
            self = .type(string)
        }
    }
}

extension FunctionDecl.ReturnType: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        self = .init(value)
    }
}
