import SwiftSyntax

extension RPCMacro {
  static func makeOutputTypes(proto: RPCProtocolInfo) throws -> DeclSyntax {
    let source = """
      private struct \(proto.name)Outputs {
        struct Nothing: Codable {}
      }
      """
    return DeclSyntax(stringLiteral: source)
  }
}
