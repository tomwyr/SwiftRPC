import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension RPCMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    // Ignore invalid config because the peer expansion already reports diagnostics.
    guard let config = try? RPCMacroConfig(from: node), config.inlineHandler else {
      return []
    }

    let proto = try protocolInfo(from: node, attachedTo: declaration)

    return [
      try makeInlineServerHandlerFactory(proto: proto)
    ]
  }

  private static func makeInlineServerHandlerFactory(
    proto: RPCProtocolInfo,
  ) throws -> ExtensionDeclSyntax {
    let protoName = proto.name
    let handlerName = "\(protoName)InlineServerHandler"
    let access = proto.access.declarationPrefix

    guard !proto.methods.isEmpty else {
      let source = """
        extension \(protoName) where Self == \(handlerName) {
          \(access)static func inline() -> \(handlerName) {
            \(handlerName)()
          }
        }
        """
      return try ExtensionDeclSyntax("\(raw: source)")
    }

    let factoryParams =
      proto.methods
      .map { method in
        "\(method.name): @escaping @Sendable \(method.closureParameterTypes) async throws -> \(method.returnType),"
      }
      .map { $0.indented(times: 2) }
      .joined(separator: "\n")

    let forwardedArgs =
      proto.methods
      .map { "\($0.handlerPropertyName): \($0.name)," }
      .map { $0.indented(times: 3) }
      .joined(separator: "\n")

    let source = """
      extension \(protoName) where Self == \(handlerName) {
        \(access)static func inline(
      \(factoryParams)
        ) -> \(handlerName) {
          \(handlerName)(
      \(forwardedArgs)
          )
        }
      }
      """

    return try ExtensionDeclSyntax("\(raw: source)")
  }
}
