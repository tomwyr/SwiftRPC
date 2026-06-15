import SwiftSyntax

extension RPCMacro {
  static func makeServer(
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
}

private func makeVariadicHandlerCall(
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

private func getVariadicCallArgs(
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

private func makeCallVariadicArguments(
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

private func makeHandlerCall(
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

private func makeHandlerCallSource(
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
