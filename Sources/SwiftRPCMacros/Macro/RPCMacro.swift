import SwiftSyntax

/// Macro implementation for the @RPC attribute.
/// Generates client and server structs from protocol definitions.
public struct RPCMacro {
  static func protocolInfo(
    from node: AttributeSyntax,
    attachedTo declaration: some SyntaxProtocol,
  ) throws -> RPCProtocolInfo {
    let proto = try validate(declaration: declaration, diagnosticNode: node)

    let access = RPCAccessLevel(from: proto.modifiers)

    let methods = proto.memberBlock.members.compactMap { member -> RPCMethod? in
      guard let fn = member.decl.as(FunctionDeclSyntax.self) else { return nil }
      return RPCMethod(from: fn)
    }

    return RPCProtocolInfo(
      name: proto.name.text,
      access: access,
      methods: methods,
    )
  }
}

extension String {
  func indented(times: Int = 1) -> String {
    let width = 2
    let spaces = String(repeating: " ", count: times * width)
    return split(separator: "\n").map { spaces + $0 }.joined(separator: "\n")
  }
}

extension ReturnClauseSyntax {
  func isVoidLike() -> Bool {
    if let tuple = type.as(TupleTypeSyntax.self) {
      tuple.elements.isEmpty
    } else if let identifier = type.as(IdentifierTypeSyntax.self) {
      identifier.name.text == "Void"
    } else {
      false
    }
  }
}

extension ReturnClauseSyntax? {
  func isVoidLike() -> Bool {
    guard let self else { return true }
    return self.isVoidLike()
  }
}
