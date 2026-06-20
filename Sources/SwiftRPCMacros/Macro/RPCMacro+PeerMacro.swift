import SwiftSyntax
import SwiftSyntaxMacros

extension RPCMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext,
  ) throws -> [DeclSyntax] {
    let config = try RPCMacroConfig(from: node)
    let proto = try protocolInfo(from: node, attachedTo: declaration, config: config)

    var declarations = [
      try makeInputTypes(proto: proto),
      try makeOutputTypes(proto: proto),
      try makeClient(proto: proto),
      try makeServer(proto: proto, config: config),
    ]

    if config.inlineHandler {
      declarations.append(
        try makeInlineHandler(proto: proto, config: config),
      )
    }

    return declarations
  }
}
