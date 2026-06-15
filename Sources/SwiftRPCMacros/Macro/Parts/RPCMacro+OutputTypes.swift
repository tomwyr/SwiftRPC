import SwiftSyntax

extension RPCMacro {
  static func makeOutputTypes(proto: RPCProtocolInfo) throws -> DeclSyntax {
    let inOutOutputs = proto.methods
      .filter(\.hasInOutParams)
      .flatMap(makeInOutOutputTypes)
      .joined(separator: "\n\n")

    let members = [
      """
      struct Nothing: Codable {}
      """,
      inOutOutputs,
    ]
    .filter { !$0.isEmpty }
    .joined(separator: "\n\n")

    let source = """
      private struct \(proto.name)Outputs {
      \(members.indented())
      }
      """
    return DeclSyntax(stringLiteral: source)
  }
}

private func makeInOutOutputTypes(method: RPCMethod) -> [String] {
  let mutationFields = method.inOutParams
    .map { "  let \($0.name): \($0.payloadType)" }
    .joined(separator: "\n")

  let outputFields = [
    method.isVoidReturn ? nil : "  let returnValue: \(method.returnType)",
    "  let mutations: \(method.mutationTypeName)",
  ].compactMap(\.self).joined(separator: "\n")

  return [
    """
    struct \(method.outputTypeName): Codable {
    \(outputFields)
    }
    """,
    """
    struct \(method.mutationTypeName): Codable {
    \(mutationFields)
    }
    """,
  ]
}
