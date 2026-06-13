import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro implementation for the @RPC attribute.
/// Generates client and server structs from protocol definitions.
public struct RPCMacro {
  private static func protocolInfo(
    from node: AttributeSyntax,
    attachedTo declaration: some SyntaxProtocol,
  ) throws -> RPCProtocolInfo {
    guard let proto = declaration.as(ProtocolDeclSyntax.self) else {
      try throwDiagnostics(node: node, message: .notAProtocol)
    }

    return try protocolInfo(from: proto)
  }

  private static func protocolInfo(from proto: ProtocolDeclSyntax) throws -> RPCProtocolInfo {
    let access = RPCAccessLevel(from: proto.modifiers)
    try validate(proto: proto)

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

  private static func inlineServerHandlerEnabled(from node: AttributeSyntax) -> Bool {
    guard case .argumentList(let args) = node.arguments,
      let handlerArg = args.first(where: { $0.label?.text == "inlineHandler" }),
      let boolHandlerArg = handlerArg.expression.as(BooleanLiteralExprSyntax.self)
    else {
      return false
    }
    return boolHandlerArg.literal.text == "true"
  }
}

extension RPCMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext,
  ) throws -> [DeclSyntax] {
    let proto = try protocolInfo(from: node, attachedTo: declaration)

    let inputsDecl = try makeInputTypes(proto: proto)
    let outputsDecl = try makeOutputTypes(proto: proto)
    let clientDecl = try makeClient(proto: proto)
    let serverDecl = try makeServer(proto: proto)

    var declarations = [inputsDecl, outputsDecl, clientDecl, serverDecl]

    if inlineServerHandlerEnabled(from: node) {
      let handlerDecl = try makeInlineServerHandler(proto: proto)
      declarations.append(handlerDecl)
    }

    return declarations
  }

  private static func makeInputTypes(proto: RPCProtocolInfo) throws -> DeclSyntax {
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
          .map { "  let \($0.name): \($0.type)" }
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

  private static func makeOutputTypes(proto: RPCProtocolInfo) throws -> DeclSyntax {
    let source = """
      private struct \(proto.name)Outputs {
        struct Nothing: Codable {}
      }
      """
    return DeclSyntax(stringLiteral: source)
  }

  private static func makeClient(proto: RPCProtocolInfo) throws -> DeclSyntax {
    let protoName = proto.name
    let clientName = "\(protoName)Client"
    let inputsName = "\(protoName)Inputs"
    let outputsName = "\(protoName)Outputs"
    let access = proto.access.declarationPrefix

    var methodDecls = [String]()

    for method in proto.methods {
      let inputTypeName = "\(inputsName).\(method.inputTypeName)"

      let paramList = method.params
        .map { "\($0.label): \($0.type)" }
        .joined(separator: ", ")
      let inputInit = method.params
        .map { "\($0.name): \($0.name)" }
        .joined(separator: ", ")

      let sendCall =
        if method.isVoidReturn {
          """
          _ = try await transport.send(
            route: "\(method.route)",
            input: input,
            outputType: \(outputsName).Nothing.self,
          )
          """
        } else {
          """
          return try await transport.send(
            route: "\(method.route)",
            input: input,
            outputType: \(method.returnType).self,
          )
          """
        }

      let returnType = method.isVoidReturn ? "" : " -> \(method.returnType)"
      let methodBody = """
        \(access)func \(method.name)(\(paramList)) async throws\(returnType) {
          let input = \(inputTypeName)(\(inputInit))
        \(sendCall.indented())
        }
        """
      methodDecls.append(methodBody)
    }

    let allMethods = methodDecls.map { $0.indented() }.joined(separator: "\n\n")

    let source = """
      \(access)struct \(clientName): \(protoName), Sendable {
        private let transport: any RPCTransport

        \(access)init(transport: any RPCTransport) {
          self.transport = transport
        }

        \(access)init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

      \(allMethods)
      }
      """

    return DeclSyntax(stringLiteral: source)
  }

  private static func makeServer(proto: RPCProtocolInfo) throws -> DeclSyntax {
    let protoName = proto.name
    let serverName = "\(protoName)Server"
    let inputsName = "\(protoName)Inputs"
    let outputsName = "\(protoName)Outputs"
    let access = proto.access.declarationPrefix

    var methodRegistrations = [String]()

    for method in proto.methods {
      // Argument forwarding: handler.getUser(id: input.id, ...)
      let callArgs = method.params
        .map { "\($0.label): input.\($0.name)" }
        .joined(separator: ", ")

      let handlerCall =
        if method.isVoidReturn {
          """
          try await self.handler.\(method.name)(\(callArgs))
          return \(outputsName).Nothing()
          """
        } else {
          "try await self.handler.\(method.name)(\(callArgs))"
        }

      let registration = """
        registry.register(method: "\(method.name)") { (input: \(inputsName).\(method.inputTypeName)) in
        \(handlerCall.indented())
        }
        """
      methodRegistrations.append(registration)
    }

    let allMethods = methodRegistrations.map { $0.indented(times: 2) }.joined(separator: "\n\n")

    let source = """
      \(access)struct \(serverName)<Handler: \(protoName) & Sendable>: RPCServer {
        private let handler: Handler

        \(access)init(handler: Handler) {
          self.handler = handler
        }

        \(access)func register(on registry: any RPCHandlerRegistry) {
      \(allMethods)
        }
      }
      """

    return DeclSyntax(stringLiteral: source)
  }

  private static func makeInlineServerHandler(proto: RPCProtocolInfo) throws -> DeclSyntax {
    let protoName = proto.name
    let handlerName = "\(protoName)InlineServerHandler"
    let access = proto.access.declarationPrefix

    let propertyDecls =
      proto.methods.map { method in
        "\(access)var \(method.handlerPropertyName): @Sendable \(method.closureParameterTypes) async throws -> \(method.returnType)"
      }
      .joined(separator: "\n")

    let methodDecls =
      proto.methods
      .map { makeInlineServerHandlerMethod(method: $0, access: proto.access) }
      .joined(separator: "\n\n")

    let structMembers = [propertyDecls, methodDecls]
      .filter { !$0.isEmpty }
      .joined(separator: "\n\n")

    let source = """
      \(access)struct \(handlerName): \(protoName), Sendable {
      \(structMembers)
      }
      """

    return DeclSyntax(stringLiteral: source)
  }

  private static func makeInlineServerHandlerMethod(
    method: RPCMethod,
    access: RPCAccessLevel,
  ) -> String {
    let access = access.declarationPrefix
    let signatureParams = method.params.map { param in
      if param.label == "_" {
        "_ \(param.name): \(param.type)"
      } else if param.label != param.name {
        "\(param.label) \(param.name): \(param.type)"
      } else {
        "\(param.label): \(param.type)"
      }
    }
    .joined(separator: ", ")

    let returnType = method.isVoidReturn ? "" : " -> \(method.returnType)"
    let forwardedArgs = method.params.map(\.name).joined(separator: ", ")

    return """
      \(access)func \(method.name)(\(signatureParams)) async throws\(returnType) {
        try await \(method.handlerPropertyName)(\(forwardedArgs))
      }
      """
  }
}

extension RPCMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard inlineServerHandlerEnabled(from: node) else {
      return []
    }

    let proto = try protocolInfo(from: node, attachedTo: declaration)

    let factoryDecl = try makeInlineServerHandlerFactory(proto: proto)

    return [factoryDecl]
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

extension RPCMacro {
  private static func validate(proto: ProtocolDeclSyntax) throws {
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
      if param.isInOut {
        diagnostics.appendDiagnostic(
          node: param.type,
          message: .inOutParameter(name: param.localName),
        )
      }

      if let ellipsis = param.ellipsis {
        diagnostics.appendDiagnostic(
          node: ellipsis,
          message: .variadicParameter(name: param.localName),
        )
      }

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

struct RPCProtocolInfo {
  let name: String
  let access: RPCAccessLevel
  let methods: [RPCMethod]
}

enum RPCAccessLevel: String {
  case `private`
  case `fileprivate`
  case `internal`
  case `package`
  case `public`

  init(from modifiers: DeclModifierListSyntax) {
    let access = modifiers.lazy.compactMap { modifier -> RPCAccessLevel? in
      switch modifier.name.text {
      case "private": .private
      case "fileprivate": .fileprivate
      case "package": .package
      case "public": .public
      case "internal": .internal
      default: nil
      }
    }.first

    self = access ?? .internal
  }

  var declarationPrefix: String {
    switch self {
    case .internal:
      ""
    case .private, .fileprivate, .package, .public:
      "\(rawValue) "
    }
  }
}

struct RPCMethod {
  let name: String
  let params: [(label: String, name: String, type: String)]
  let returnType: String
  let isVoidReturn: Bool

  init(from fn: FunctionDeclSyntax) {
    name = fn.name.text

    params = fn.signature.parameterClause.parameters.map { param in
      let label = param.firstName.text
      let name = param.secondName?.text ?? label
      let type = param.type.trimmedDescription
      return (label: label, name: name, type: type)
    }

    let returnClause = fn.signature.returnClause
    returnType = returnClause?.type.trimmedDescription ?? "Void"
    isVoidReturn = returnClause.isVoidLike()
  }

  /// The internal input struct name, e.g. `GetUser`
  var inputTypeName: String {
    "\(name.prefix(1).uppercased())\(name.dropFirst())"
  }

  /// The route path, e.g. `/getUser`
  var route: String { "/\(name)" }

  var handlerPropertyName: String {
    "\(name)Handler"
  }

  var closureParameterTypes: String {
    let types = params.map(\.type).joined(separator: ", ")
    return "(\(types))"
  }
}

enum RPCMacroError: Error, CustomStringConvertible {
  case notAProtocol
  case associatedTypesAreUnsupported(name: String)
  case genericMethod(name: String)
  case overloadedMethod(name: String)
  case inOutParameter(name: String)
  case methodMustBeAsyncThrows(name: String)
  case parameterTypeMustBeCodable(name: String)
  case returnTypeMustBeCodable(name: String)
  case variadicParameter(name: String)

  var description: String {
    switch self {
    case .notAProtocol:
      "@RPC can only be applied to a protocol"
    case .associatedTypesAreUnsupported(let name):
      "@RPC: associated type '\(name)' is not supported"
    case .genericMethod(let name):
      "@RPC: '\(name)' must not be generic"
    case .overloadedMethod(let name):
      "@RPC: overloaded method '\(name)' is not supported"
    case .inOutParameter(let name):
      "@RPC: parameter '\(name)' must not be inout"
    case .methodMustBeAsyncThrows(let name):
      "@RPC: '\(name)' must be declared 'async throws'"
    case .parameterTypeMustBeCodable(let name):
      "@RPC: parameter '\(name)' must use a Codable-compatible type"
    case .returnTypeMustBeCodable(let name):
      "@RPC: return type of '\(name)' must be Codable-compatible"
    case .variadicParameter(let name):
      "@RPC: parameter '\(name)' must not be variadic"
    }
  }
}

extension RPCMacroError: DiagnosticMessage {
  var message: String {
    description
  }

  var diagnosticID: MessageID {
    let errorName = String(describing: self).replacing(/\(.*/, with: "")
    return MessageID(domain: "SwiftRPCMacros", id: errorName)
  }

  var severity: DiagnosticSeverity {
    .error
  }
}

private func throwDiagnostics(
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

extension String {
  fileprivate func indented(times: Int = 1) -> String {
    let width = 2
    let spaces = String(repeating: " ", count: times * width)
    return split(separator: "\n").map { spaces + $0 }.joined(separator: "\n")
  }
}

extension FunctionDeclSyntax {
  fileprivate var isAsyncThrows: Bool {
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
