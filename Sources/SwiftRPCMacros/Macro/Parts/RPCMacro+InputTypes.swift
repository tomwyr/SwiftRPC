import SwiftSyntax

extension RPCMacro {
  static func makeInputTypes(proto: RPCProtocolInfo) throws -> DeclSyntax {
    let protoName = proto.name
    let structName = "\(protoName)Inputs"

    var memberDecls = [String]()

    for method in proto.methods {
      if method.params.isEmpty {
        memberDecls.append(
          """
          struct \(method.inputTypeName): Codable {
          }
          """
        )
      } else {
        let fields = method.params
          .map { "  let \($0.name): \($0.payloadType)" }
          .joined(separator: "\n")

        memberDecls.append(
          """
          struct \(method.inputTypeName): Codable {
          \(fields)
          }
          """)
      }
    }

    let allInputStructs = memberDecls.joined(separator: "\n\n")

    let source = """
      private struct \(structName) {
      \(allInputStructs)
      }
      """

    return DeclSyntax(stringLiteral: source)
  }
}
