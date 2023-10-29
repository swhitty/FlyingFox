//
//  CustomError.swift
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

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

enum CustomError: Error, CustomStringConvertible {
  case message(String)

  var description: String {
    switch self {
    case .message(let text):
      return text
    }
  }
}

struct SimpleDiagnostic: DiagnosticMessage {
    var message: String
    var diagnosticID: MessageID
    var severity: DiagnosticSeverity

    static func warning(_ message: String) -> Self {
        SimpleDiagnostic(
            message: message,
            diagnosticID: .init(domain: "Macro", id: message),
            severity: .warning
        )
    }
}

extension MacroExpansionContext {

    func diagnoseWarning(for node: some SyntaxProtocol, _ message: String) {
        diagnose(
          Diagnostic(
            node: node,
            message: SimpleDiagnostic.warning(message)
          )
        )
    }
}
