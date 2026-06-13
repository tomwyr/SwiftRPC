import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro implementation for the @RPC attribute.
/// Generates client and server structs from protocol definitions.
public struct RPCMacro {
  private static func protocolInfo(
    from declaration: some SyntaxProtocol
  ) throws -> RPCProtocolInfo {
    guard let proto = declaration.as(ProtocolDeclSyntax.self) else {
      throw RPCMacroError.notAProtocol
    }

    let access = RPCAccessLevel(from: proto.modifiers)

    let methods = try proto.memberBlock.members.compactMap { member -> RPCMethod? in
      guard let fn = member.decl.as(FunctionDeclSyntax.self) else { return nil }
      return try RPCMethod(from: fn)
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
    let proto = try protocolInfo(from: declaration)

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

    let proto = try protocolInfo(from: declaration)

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

  init(from fn: FunctionDeclSyntax) throws {
    name = fn.name.text

    guard let effect = fn.signature.effectSpecifiers,
      effect.asyncSpecifier != nil,
      effect.throwsClause?.throwsSpecifier != nil
    else {
      throw RPCMacroError.methodMustBeAsyncThrows(name: fn.name.text)
    }

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
  case methodMustBeAsyncThrows(name: String)

  var description: String {
    switch self {
    case .notAProtocol:
      "@RPC can only be applied to a protocol"
    case .methodMustBeAsyncThrows(let name):
      "@RPC: '\(name)' must be declared 'async throws'"
    }
  }
}

extension String {
  fileprivate func indented(times: Int = 1) -> String {
    let width = 2
    let spaces = String(repeating: " ", count: times * width)
    return split(separator: "\n").map { spaces + $0 }.joined(separator: "\n")
  }
}

extension ReturnClauseSyntax? {
  func isVoidLike() -> Bool {
    guard let type = self?.type else { return true }

    return if let tuple = type.as(TupleTypeSyntax.self) {
      tuple.elements.isEmpty
    } else if let identifier = type.as(IdentifierTypeSyntax.self) {
      identifier.name.text == "Void"
    } else {
      false
    }
  }
}
