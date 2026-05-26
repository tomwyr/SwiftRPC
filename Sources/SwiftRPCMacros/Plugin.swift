import SwiftCompilerPlugin
import SwiftSyntaxMacros

/// Compiler plugin providing the @RPC macro.
@main
struct SwiftRPCPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [RPCMacro.self]
}
