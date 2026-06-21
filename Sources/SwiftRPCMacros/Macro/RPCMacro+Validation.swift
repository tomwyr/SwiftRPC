import SwiftDiagnostics
import SwiftSyntax

extension RPCMacro {
  static func validate(
    declaration: some SyntaxProtocol,
    diagnosticNode: some SyntaxProtocol,
  ) throws -> ProtocolDeclSyntax {
    guard let proto = declaration.as(ProtocolDeclSyntax.self) else {
      try throwDiagnostics(node: diagnosticNode, message: .notAProtocol)
    }

    try validate(proto: proto)
    return proto
  }

  static func validate(proto: ProtocolDeclSyntax) throws {
    var diagnostics = [Diagnostic]()
    var functionsByName = [String: [FunctionDeclSyntax]]()

    for member in proto.memberBlock.members {
      if let associatedType = member.decl.as(AssociatedTypeDeclSyntax.self) {
        diagnostics.appendDiagnostic(
          node: associatedType.name,
          message: .associatedTypesAreUnsupported(name: associatedType.name.text),
        )
        continue
      }

      guard let fn = member.decl.as(FunctionDeclSyntax.self) else {
        continue
      }

      functionsByName[fn.name.text, default: []].append(fn)
      validate(method: fn, diagnostics: &diagnostics)
    }

    for functions in functionsByName.values where functions.count > 1 {
      for fn in functions {
        diagnostics.appendDiagnostic(
          node: fn.name,
          message: .overloadedMethod(name: fn.name.text),
        )
      }
    }

    guard diagnostics.isEmpty else {
      throw DiagnosticsError(diagnostics: diagnostics)
    }
  }

  private static func validate(
    method fn: FunctionDeclSyntax,
    diagnostics: inout [Diagnostic],
  ) {
    if fn.genericParameterClause != nil {
      diagnostics.appendDiagnostic(
        node: fn.name,
        message: .genericMethod(name: fn.name.text),
      )
    }

    if !fn.isAsyncThrows {
      diagnostics.appendDiagnostic(
        node: fn.name,
        message: .methodMustBeAsyncThrows(name: fn.name.text),
      )
    }

    for param in fn.signature.parameterClause.parameters {
      validateCodableType(
        param.type,
        message: .parameterTypeMustBeCodable(name: param.localName),
        diagnostics: &diagnostics,
      )
    }

    if let returnClause = fn.signature.returnClause, !returnClause.isVoidLike() {
      validateCodableType(
        returnClause.type,
        message: .returnTypeMustBeCodable(name: fn.name.text),
        diagnostics: &diagnostics,
      )
    }
  }

  private static func validateCodableType(
    _ type: TypeSyntax,
    message: RPCMacroError,
    diagnostics: inout [Diagnostic],
  ) {
    if type.is(FunctionTypeSyntax.self)
      || type.is(TupleTypeSyntax.self)
      || type.is(MetatypeTypeSyntax.self)
    {
      diagnostics.appendDiagnostic(node: type, message: message)
      return
    }

    if let identifier = type.as(IdentifierTypeSyntax.self) {
      if ["Any", "AnyObject", "Self"].contains(identifier.name.text) {
        diagnostics.appendDiagnostic(node: identifier.name, message: message)
        return
      }

      validateCodableTypes(
        in: identifier.genericArgumentClause,
        message: message,
        diagnostics: &diagnostics,
      )
      return
    }

    if let optional = type.as(OptionalTypeSyntax.self) {
      validateCodableType(optional.wrappedType, message: message, diagnostics: &diagnostics)
      return
    }

    if let implicitlyUnwrappedOptional = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
      validateCodableType(
        implicitlyUnwrappedOptional.wrappedType,
        message: message,
        diagnostics: &diagnostics,
      )
      return
    }

    if let array = type.as(ArrayTypeSyntax.self) {
      validateCodableType(array.element, message: message, diagnostics: &diagnostics)
      return
    }

    if let dictionary = type.as(DictionaryTypeSyntax.self) {
      validateCodableType(dictionary.key, message: message, diagnostics: &diagnostics)
      validateCodableType(dictionary.value, message: message, diagnostics: &diagnostics)
      return
    }

    if let attributed = type.as(AttributedTypeSyntax.self) {
      validateCodableType(attributed.baseType, message: message, diagnostics: &diagnostics)
      return
    }

    if let member = type.as(MemberTypeSyntax.self) {
      validateCodableType(member.baseType, message: message, diagnostics: &diagnostics)
      validateCodableTypes(
        in: member.genericArgumentClause,
        message: message,
        diagnostics: &diagnostics,
      )
      return
    }
  }

  private static func validateCodableTypes(
    in genericArgumentClause: GenericArgumentClauseSyntax?,
    message: RPCMacroError,
    diagnostics: inout [Diagnostic],
  ) {
    guard let genericArgumentClause else { return }

    for argument in genericArgumentClause.arguments {
      switch argument.argument {
      case .type(let type):
        validateCodableType(type, message: message, diagnostics: &diagnostics)
      case .expr:
        continue
      }
    }
  }
}

func throwDiagnostics(
  node: some SyntaxProtocol,
  message: RPCMacroError,
) throws -> Never {
  var diagnostics = [Diagnostic]()
  diagnostics.appendDiagnostic(node: node, message: message)
  throw DiagnosticsError(diagnostics: diagnostics)
}

extension Array where Element == Diagnostic {
  mutating func appendDiagnostic(
    node: some SyntaxProtocol,
    message: RPCMacroError,
  ) {
    append(Diagnostic(node: node, message: message))
  }
}

extension FunctionDeclSyntax {
  var isAsyncThrows: Bool {
    guard let effect = signature.effectSpecifiers else {
      return false
    }

    return effect.asyncSpecifier != nil
      && effect.throwsClause?.throwsSpecifier != nil
  }
}

extension FunctionParameterSyntax {
  var localName: String {
    (secondName ?? firstName).text
  }

  var isInOut: Bool {
    guard let attributed = type.as(AttributedTypeSyntax.self) else {
      return false
    }

    for specifier in attributed.specifiers {
      if specifier.as(SimpleTypeSpecifierSyntax.self)?.specifier.text == "inout" {
        return true
      }
    }

    return false
  }
}
