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
    let serviceErrorType = proto.serviceErrorType

    var methodRegistrations = [String]()

    for method in proto.methods {
      let methodServiceErrorType = method.responseServiceErrorType(default: serviceErrorType)
      let handlerCall =
        if let variadicParam = method.variadicParam {
          makeVariadicHandlerCall(
            method: method,
            variadicParam: variadicParam,
            outputsName: outputsName,
            config: config,
          )
        } else {
          makeHandlerCall(
            method: method,
            outputsName: outputsName,
            explicitReturn: methodServiceErrorType != nil,
          )
        }

      let registrationBody =
        if let methodServiceErrorType {
          makeTypedErrorHandlerCall(
            handlerCall,
            serviceErrorType: methodServiceErrorType,
            typedFailureServiceErrorType: method.failureServiceErrorType,
          )
        } else {
          handlerCall
        }

      let registration = """
        registry.register(method: "\(method.name)") { (input: \(inputsName).\(method.inputTypeName)) in
        \(registrationBody.indented())
        }
        """
      methodRegistrations.append(registration)
    }

    let allMethods = methodRegistrations.map { $0.indented(times: 2) }.joined(separator: "\n\n")
    let storedProperties = "private let handler: Handler"

    let serverInit = """
      \(access)init(handler: Handler) {
        self.handler = handler
      }
      """

    let source = """
      \(access)struct \(serverName)<Handler: \(protoName) & Sendable>: RPCServer {
      \(storedProperties.indented())

      \(serverInit.indented())

        \(access)func register(on registry: any RPCHandlerRegistry) {
      \(allMethods)
        }
      }
      """

    return DeclSyntax(stringLiteral: source)
  }
}

private func makeTypedErrorHandlerCall(
  _ handlerCall: String,
  serviceErrorType: String,
  typedFailureServiceErrorType: String?,
) -> String {
  let typedFailureCatch =
    if let typedFailureServiceErrorType {
      """
      } catch let error as RPCFailure<\(typedFailureServiceErrorType)> {
        switch error {
        case .rpc(let error):
          throw error
        case .service(let error):
          throw RPCServiceErrorEnvelope(error)
        }
      """
    } else {
      ""
    }

  let serviceErrorCatch =
    if typedFailureServiceErrorType == nil {
      """
      } catch let error as \(serviceErrorType) {
        throw RPCServiceErrorEnvelope(error)
      """
    } else {
      ""
    }

  return """
    do {
    \(handlerCall.indented())
    \(typedFailureCatch)
    } catch let error as RPCError {
      throw error
    } catch let error as RPCServiceErrorEnvelope {
      throw error
    \(serviceErrorCatch)
    }
    """
}

private func makeVariadicHandlerCall(
  method: RPCMethod,
  variadicParam: RPCParameter,
  outputsName: String,
  config: RPCMacroConfig,
) -> String {
  let cases = (0...config.varargMaxArity).map { arity in
    let callArgs = getVariadicCallArgs(
      method: method,
      variadicParam: variadicParam,
      variadicArity: arity,
    )
    let handlerCall = makeHandlerCallSource(
      method: method,
      outputsName: outputsName,
      callArgs: callArgs,
      explicitReturn: true,
    )

    return """
      case \(arity):
      \(handlerCall.indented())
      """
  }.joined(separator: "\n")

  let defaultCase: String
  switch config.varargOverflowBehavior {
  case .reject:
    defaultCase =
      """
      default:
        throw RPCError(
          code: .badRequest,
          message: "Variadic parameter '\(variadicParam.name)' exceeds the maximum of \(config.varargMaxArity) arguments",
        )
      """
  case .truncate:
    let callArgs = getVariadicCallArgs(
      method: method,
      variadicParam: variadicParam,
      variadicArity: config.varargMaxArity,
    )
    let handlerCall = makeHandlerCallSource(
      method: method,
      outputsName: outputsName,
      callArgs: callArgs,
      explicitReturn: true,
    )

    defaultCase =
      """
      default:
      \(handlerCall.indented())
      """
  }

  let inOutVariables = makeInOutVariables(method: method)

  let switchSource = """
    switch input.\(variadicParam.name).count {
    \(cases.indented())
    \(defaultCase.indented())
    }
    """

  return [inOutVariables, switchSource]
    .filter { !$0.isEmpty }
    .joined(separator: "\n")
}

private func getVariadicCallArgs(
  method: RPCMethod,
  variadicParam: RPCParameter,
  variadicArity: Int,
) -> String {
  method.params.flatMap { param in
    if param.name == variadicParam.name {
      makeCallVariadicArguments(for: param, arity: variadicArity)
    } else if param.isInOut {
      [param.callArgument(value: "&\(param.name)")]
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
  let callArgs = method.params.map { param in
    if param.isInOut {
      param.callArgument(value: "&\(param.name)")
    } else {
      param.callArgument(value: "input.\(param.name)")
    }
  }.joined(separator: ", ")

  return makeHandlerCallSource(
    method: method,
    outputsName: outputsName,
    inOutVariables: makeInOutVariables(method: method),
    callArgs: callArgs,
    explicitReturn: explicitReturn,
  )
}

private func makeHandlerCallSource(
  method: RPCMethod,
  outputsName: String,
  inOutVariables: String? = nil,
  callArgs: String,
  explicitReturn: Bool,
) -> String {
  let call = "try await self.handler.\(method.name)(\(callArgs))"

  if !method.hasInOutParams {
    if method.isVoidReturn {
      return """
        \(call)
        return \(outputsName).Nothing()
        """
    }

    let returnPrefix = explicitReturn ? "return " : ""
    return "\(returnPrefix)\(call)"
  } else {
    let callSource =
      if method.isVoidReturn {
        call
      } else {
        "let returnValue = \(call)"
      }

    let mutationInit = method.inOutParams
      .map { "\($0.name): \($0.name)" }
      .joined(separator: ", ")

    let outputInit =
      if method.isVoidReturn {
        """
        \(outputsName).\(method.outputTypeName)(
          mutations: \(outputsName).\(method.mutationTypeName)(\(mutationInit))
        )
        """
      } else {
        """
        \(outputsName).\(method.outputTypeName)(
          returnValue: returnValue,
          mutations: \(outputsName).\(method.mutationTypeName)(\(mutationInit))
        )
        """
      }

    return [
      inOutVariables,
      """
      \(callSource)
      return \(outputInit)
      """,
    ]
    .compactMap(\.self)
    .joined(separator: "\n")
  }
}

private func makeInOutVariables(method: RPCMethod) -> String {
  method.inOutParams
    .map { "var \($0.name) = input.\($0.name)" }
    .joined(separator: "\n")
}
