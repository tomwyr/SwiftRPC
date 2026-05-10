import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftRPCPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [RPCMacro.self]
}
