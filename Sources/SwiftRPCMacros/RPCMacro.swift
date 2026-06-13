import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro implementation for the @RPC attribute.
/// Generates client and server structs from protocol definitions.
public struct RPCMacro {
  private static func protocolInfo(
    from declaration: some SyntaxProtocol
  ) throws -> (name: String, methods: [RPCMethod]) {
    guard let proto = declaration.as(ProtocolDeclSyntax.self) else {
      throw RPCMacroError.notAProtocol
    }

    let methods = try proto.memberBlock.members.compactMap { member -> RPCMethod? in
      guard let fn = member.decl.as(FunctionDeclSyntax.self) else { return nil }
      return try RPCMethod(from: fn)
    }

    return (name: proto.name.text, methods: methods)
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
    let (protoName, methods) = try protocolInfo(from: declaration)

    let inputsDecl = try makeInputTypes(protoName: protoName, methods: methods)
    let outputsDecl = try makeOutputTypes(protoName: protoName, methods: methods)
    let clientDecl = try makeClient(protoName: protoName, methods: methods)
    let serverDecl = try makeServer(protoName: protoName, methods: methods)

    var declarations = [inputsDecl, outputsDecl, clientDecl, serverDecl]

    if inlineServerHandlerEnabled(from: node) {
      let handlerDecl = try makeInlineServerHandler(protoName: protoName, methods: methods)
      declarations.append(handlerDecl)
    }

    return declarations
  }

  private static func makeInputTypes(protoName: String, methods: [RPCMethod]) throws -> DeclSyntax {
    let structName = "\(protoName)Inputs"

    var memberDecls = [String]()

    for method in methods {
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

  private static func makeOutputTypes(protoName: String, methods: [RPCMethod]) throws -> DeclSyntax
  {
    let source = """
      private struct \(protoName)Outputs {
        struct Nothing: Codable {}
      }
      """
    return DeclSyntax(stringLiteral: source)
  }

  private static func makeClient(protoName: String, methods: [RPCMethod]) throws -> DeclSyntax {
    let clientName = "\(protoName)Client"
    let inputsName = "\(protoName)Inputs"
    let outputsName = "\(protoName)Outputs"

    var methodDecls = [String]()

    for method in methods {
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
        func \(method.name)(\(paramList)) async throws\(returnType) {
          let input = \(inputTypeName)(\(inputInit))
        \(sendCall.indented())
        }
        """
      methodDecls.append(methodBody)
    }

    let allMethods = methodDecls.map { $0.indented() }.joined(separator: "\n\n")

    let source = """
      struct \(clientName): \(protoName), Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

      \(allMethods)
      }
      """

    return DeclSyntax(stringLiteral: source)
  }

  private static func makeServer(
    protoName: String,
    methods: [RPCMethod],
  ) throws -> DeclSyntax {
    let serverName = "\(protoName)Server"
    let inputsName = "\(protoName)Inputs"
    let outputsName = "\(protoName)Outputs"

    var methodRegistrations = [String]()

    for method in methods {
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
      struct \(serverName)<Handler: \(protoName) & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
      \(allMethods)
        }
      }
      """

    return DeclSyntax(stringLiteral: source)
  }

  private static func makeInlineServerHandler(protoName: String, methods: [RPCMethod]) throws
    -> DeclSyntax
  {
    let handlerName = "\(protoName)InlineServerHandler"

    let propertyDecls =
      methods.map { method in
        "var \(method.handlerPropertyName): @Sendable \(method.closureParameterTypes) async throws -> \(method.returnType)"
      }
      .joined(separator: "\n")

    let methodDecls =
      methods
      .map(makeInlineServerHandlerMethod)
      .joined(separator: "\n\n")

    let structMembers = [propertyDecls, methodDecls]
      .filter { !$0.isEmpty }
      .joined(separator: "\n\n")

    let source = """
      struct \(handlerName): \(protoName), Sendable {
      \(structMembers)
      }
      """

    return DeclSyntax(stringLiteral: source)
  }

  private static func makeInlineServerHandlerMethod(method: RPCMethod) -> String {
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
      func \(method.name)(\(signatureParams)) async throws\(returnType) {
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

    let (_, methods) = try protocolInfo(from: declaration)

    let factoryDecl = try makeInlineServerHandlerFactory(
      protoName: type.trimmedDescription,
      methods: methods,
    )

    return [factoryDecl]
  }

  private static func makeInlineServerHandlerFactory(
    protoName: String, methods: [RPCMethod],
  ) throws -> ExtensionDeclSyntax {
    let handlerName = "\(protoName)InlineServerHandler"

    guard !methods.isEmpty else {
      let source = """
        extension \(protoName) where Self == \(handlerName) {
          static func inline() -> \(handlerName) {
            \(handlerName)()
          }
        }
        """
      return try ExtensionDeclSyntax("\(raw: source)")
    }

    let factoryParams =
      methods
      .map { method in
        "\(method.name): @escaping @Sendable \(method.closureParameterTypes) async throws -> \(method.returnType),"
      }
      .map { $0.indented(times: 2) }
      .joined(separator: "\n")

    let forwardedArgs =
      methods
      .map { "\($0.handlerPropertyName): \($0.name)," }
      .map { $0.indented(times: 3) }
      .joined(separator: "\n")

    let source = """
      extension \(protoName) where Self == \(handlerName) {
        static func inline(
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
