import SwiftSyntax
import SwiftSyntaxMacros

extension RPCMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext,
  ) throws -> [DeclSyntax] {
    let config = try RPCMacroConfig(from: node)
    let proto = try protocolInfo(from: node, attachedTo: declaration)

    var declarations = [
      try makeInputTypes(proto: proto),
      try makeOutputTypes(proto: proto),
      try makeClient(proto: proto),
      try makeServer(proto: proto, config: config),
    ]

    if config.inlineHandler {
      declarations.append(
        try makeInlineHandler(proto: proto, config: config),
      )
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
        .map(\.signatureFragment)
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

  private static func makeServer(
    proto: RPCProtocolInfo,
    config: RPCMacroConfig,
  ) throws -> DeclSyntax {
    let protoName = proto.name
    let serverName = "\(protoName)Server"
    let inputsName = "\(protoName)Inputs"
    let outputsName = "\(protoName)Outputs"
    let access = proto.access.declarationPrefix

    var methodRegistrations = [String]()

    for method in proto.methods {
      let handlerCall =
        if let variadicParam = method.variadicParam {
          makeVariadicHandlerCall(
            method: method,
            variadicParam: variadicParam,
            outputsName: outputsName,
            config: config,
          )
        } else {
          makeHandlerCall(method: method, outputsName: outputsName)
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

  private static func makeVariadicHandlerCall(
    method: RPCMethod,
    variadicParam: RPCParameter,
    outputsName: String,
    config: RPCMacroConfig,
  ) -> String {
    let cases = (0...config.varargMaxArity).map { arity in
      """
      case \(arity):
      \(makeHandlerCallSource(
        method: method,
        outputsName: outputsName,
        callArgs: getVariadicCallArgs(
          method: method,
          variadicParam: variadicParam, variadicArity: arity,
        ),
        explicitReturn: true,
      ).indented())
      """
    }.joined(separator: "\n")

    let defaultCase =
      switch config.varargOverflowBehavior {
      case .reject:
        """
        default:
          throw RPCError(
            code: .badRequest,
            message: "Variadic parameter '\(variadicParam.name)' exceeds the maximum of \(config.varargMaxArity) arguments",
          )
        """
      case .truncate:
        """
        default:
        \(makeHandlerCallSource(
          method: method,
          outputsName: outputsName,
          callArgs: getVariadicCallArgs(
            method: method, 
            variadicParam: variadicParam, variadicArity: config.varargMaxArity,
          ),
          explicitReturn: true,
        ).indented())
        """
      }

    return """
      switch input.\(variadicParam.name).count {
      \(cases.indented())
      \(defaultCase.indented())
      }
      """
  }

  private static func getVariadicCallArgs(
    method: RPCMethod,
    variadicParam: RPCParameter,
    variadicArity: Int,
  ) -> String {
    method.params.flatMap { param in
      if param.name == variadicParam.name {
        makeCallVariadicArguments(for: param, arity: variadicArity)
      } else {
        [param.callArgument(value: "input.\(param.name)")]
      }
    }.joined(separator: ", ")
  }

  private static func makeCallVariadicArguments(
    for param: RPCParameter, arity: Int,
  ) -> [String] {
    (0..<arity).map { index in
      let value = "input.\(param.name)[\(index)]"
      if index == 0 {
        return param.callArgument(value: value)
      }
      return value
    }
  }

  private static func makeHandlerCall(
    method: RPCMethod,
    outputsName: String,
    explicitReturn: Bool = false,
  ) -> String {
    let callArgs = method.params
      .map { param in param.callArgument(value: "input.\(param.name)") }
      .joined(separator: ", ")

    return makeHandlerCallSource(
      method: method,
      outputsName: outputsName,
      callArgs: callArgs,
      explicitReturn: explicitReturn,
    )
  }

  private static func makeHandlerCallSource(
    method: RPCMethod,
    outputsName: String,
    callArgs: String,
    explicitReturn: Bool,
  ) -> String {
    let call = "try await self.handler.\(method.name)(\(callArgs))"

    if method.isVoidReturn {
      return """
        \(call)
        return \(outputsName).Nothing()
        """
    }

    let returnPrefix = explicitReturn ? "return " : ""
    return "\(returnPrefix)\(call)"
  }

  private static func makeInlineHandler(
    proto: RPCProtocolInfo,
    config: RPCMacroConfig,
  ) throws -> DeclSyntax {
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
      .map { makeInlineHandlerMethod(method: $0, access: proto.access, config: config) }
      .joined(separator: "\n\n")

    let allMembers = [propertyDecls, methodDecls]
      .filter { !$0.isEmpty }
      .joined(separator: "\n\n")

    let source = """
      \(access)struct \(handlerName): \(protoName), Sendable {
      \(allMembers)
      }
      """

    return DeclSyntax(stringLiteral: source)
  }

  private static func makeInlineHandlerMethod(
    method: RPCMethod,
    access: RPCAccessLevel,
    config: RPCMacroConfig,
  ) -> String {
    let access = access.declarationPrefix
    let signatureParams = method.params.map(\.signatureFragment).joined(separator: ", ")

    let returnType = method.isVoidReturn ? "" : " -> \(method.returnType)"
    let body =
      if let variadicParam = method.variadicParam {
        makeVariadicInlineHandlerCall(
          method: method,
          variadicParam: variadicParam,
          config: config,
        )
      } else {
        makeInlineHandlerCall(method: method)
      }

    return """
      \(access)func \(method.name)(\(signatureParams)) async throws\(returnType) {
      \(body.indented())
      }
      """
  }

  private static func makeVariadicInlineHandlerCall(
    method: RPCMethod,
    variadicParam: RPCParameter,
    config: RPCMacroConfig,
  ) -> String {
    let cases = (0...config.varargMaxArity).map { arity in
      """
      case \(arity):
      \(makeVariadicInlineHandlerCall(
        method: method,
        variadicParam: variadicParam,
        variadicArity: arity,
        explicitReturn: true
      ).indented())
      """
    }.joined(separator: "\n")

    let defaultCase =
      switch config.varargOverflowBehavior {
      case .reject:
        """
        default:
          throw RPCError(
            code: .badRequest,
            message: "Variadic parameter '\(variadicParam.name)' exceeds the maximum of \(config.varargMaxArity) arguments",
          )
        """
      case .truncate:
        """
        default:
        \(makeVariadicInlineHandlerCall(
          method: method,
          variadicParam: variadicParam,
          variadicArity: config.varargMaxArity,
          explicitReturn: true
        ).indented())
        """
      }

    return """
      switch \(variadicParam.name).count {
      \(cases.indented())
      \(defaultCase.indented())
      }
      """
  }

  private static func makeInlineHandlerCall(
    method: RPCMethod,
    explicitReturn: Bool = false,
  ) -> String {
    let forwardedArgs = method.params
      .map(\.name)
      .joined(separator: ", ")

    return makeInlineHandlerCallSource(
      method: method,
      forwardedArgs: forwardedArgs,
      explicitReturn: explicitReturn,
    )
  }

  private static func makeVariadicInlineHandlerCall(
    method: RPCMethod,
    variadicParam: RPCParameter,
    variadicArity: Int,
    explicitReturn: Bool,
  ) -> String {
    let forwardedArgs = method.params.flatMap { param in
      if param.name == variadicParam.name {
        param.closureVariadicArguments(arity: variadicArity)
      } else {
        [param.name]
      }
    }.joined(separator: ", ")

    return makeInlineHandlerCallSource(
      method: method,
      forwardedArgs: forwardedArgs,
      explicitReturn: explicitReturn,
    )
  }

  private static func makeInlineHandlerCallSource(
    method: RPCMethod,
    forwardedArgs: String,
    explicitReturn: Bool,
  ) -> String {
    let call = "try await \(method.handlerPropertyName)(\(forwardedArgs))"

    if method.isVoidReturn {
      return call
    }

    let returnPrefix = explicitReturn ? "return " : ""
    return "\(returnPrefix)\(call)"
  }

  private static func getInlineVariadicCallArgs(
    method: RPCMethod,
    variadicParam: RPCParameter,
    variadicArity: Int,
  ) -> String {
    method.params.flatMap { param in
      if param.name == variadicParam.name {
        param.closureVariadicArguments(arity: variadicArity)
      } else {
        [param.name]
      }
    }.joined(separator: ", ")
  }
}
