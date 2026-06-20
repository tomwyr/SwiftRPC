import SwiftSyntax

extension RPCMacro {
  static func makeInlineHandler(
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
}

private func makeInlineHandlerMethod(
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

private func makeVariadicInlineHandlerCall(
  method: RPCMethod,
  variadicParam: RPCParameter,
  config: RPCMacroConfig,
) -> String {
  let cases = (0...config.varargMaxArity).map { arity in
    let handlerCall = makeVariadicInlineHandlerCall(
      method: method,
      variadicParam: variadicParam,
      variadicArity: arity,
      explicitReturn: true
    )

    return """
    case \(arity):
    \(handlerCall.indented())
    """
  }.joined(separator: "\n")

  let defaultCase: String
  switch config.varargOverflowBehavior {
  case .reject:
    defaultCase = """
      default:
        throw RPCError(
          code: .badRequest,
          message: "Variadic parameter '\(variadicParam.name)' exceeds the maximum of \(config.varargMaxArity) arguments",
        )
      """
  case .truncate:
    let handlerCall = makeVariadicInlineHandlerCall(
      method: method,
      variadicParam: variadicParam,
      variadicArity: config.varargMaxArity,
      explicitReturn: true
    )

    defaultCase = """
      default:
      \(handlerCall.indented())
      """
  }

  return """
    switch \(variadicParam.name).count {
    \(cases.indented())
    \(defaultCase.indented())
    }
    """
}

private func makeInlineHandlerCall(
  method: RPCMethod,
  explicitReturn: Bool = false,
) -> String {
  let forwardedArgs = method.params
    .map { $0.isInOut ? "&\($0.name)" : $0.name }
    .joined(separator: ", ")

  return makeInlineHandlerCallSource(
    method: method,
    forwardedArgs: forwardedArgs,
    explicitReturn: explicitReturn,
  )
}

private func makeVariadicInlineHandlerCall(
  method: RPCMethod,
  variadicParam: RPCParameter,
  variadicArity: Int,
  explicitReturn: Bool,
) -> String {
  let forwardedArgs = method.params.flatMap { param in
    if param.name == variadicParam.name {
      param.closureVariadicArguments(arity: variadicArity)
    } else if param.isInOut {
      ["&\(param.name)"]
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

private func makeInlineHandlerCallSource(
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
