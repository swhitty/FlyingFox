import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MyMacroPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        HTTPRouteMacro.self,
        JSONRouteMacro.self,
        HTTPHandlerMacro.self
    ]
}
