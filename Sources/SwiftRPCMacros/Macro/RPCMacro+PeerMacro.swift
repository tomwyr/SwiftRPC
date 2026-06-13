import SwiftSyntax
import SwiftSyntaxMacros

extension RPCMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext,
  ) throws -> [DeclSyntax] {
    let config = RPCMacroConfig(from: node)
    let proto = try protocolInfo(from: node, attachedTo: declaration)

    let inputsDecl = try makeInputTypes(proto: proto)
    let outputsDecl = try makeOutputTypes(proto: proto)
    let clientDecl = try makeClient(proto: proto)
    let serverDecl = try makeServer(proto: proto)

    var declarations = [inputsDecl, outputsDecl, clientDecl, serverDecl]

    if config.inlineHandler {
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
