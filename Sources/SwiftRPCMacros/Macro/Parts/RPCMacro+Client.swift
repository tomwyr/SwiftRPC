import SwiftSyntax

extension RPCMacro {
  static func makeClient(proto: RPCProtocolInfo) throws -> DeclSyntax {
    let protoName = proto.name
    let clientName = "\(protoName)Client"
    let inputsName = "\(protoName)Inputs"
    let outputsName = "\(protoName)Outputs"
    let access = proto.access.declarationPrefix
    let serviceErrorType = proto.serviceErrorType

    var methodDecls = [String]()

    for method in proto.methods {
      let inputTypeName = "\(inputsName).\(method.inputTypeName)"

      let paramList = method.params
        .map(\.signatureFragment)
        .joined(separator: ", ")
      let inputInit = method.params
        .map { "\($0.name): \($0.name)" }
        .joined(separator: ", ")

      let sendCall = makeSendCall(
        method: method,
        outputsName: outputsName,
        serviceErrorType: serviceErrorType,
      )

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
    let storedProperties = "private let transport: any RPCTransport"

    let transportInit = """
      \(access)init(transport: any RPCTransport) {
        self.transport = transport
      }
      """

    let baseURLInit = """
      \(access)init(baseURL: URL) {
        self.transport = HTTPTransport(baseURL: baseURL)
      }
      """

    let source = """
      \(access)struct \(clientName): \(protoName), Sendable {
      \(storedProperties.indented())

      \(transportInit.indented())

      \(baseURLInit.indented())

      \(allMethods)
      }
      """

    return DeclSyntax(stringLiteral: source)
  }
}

private func makeSendCall(
  method: RPCMethod,
  outputsName: String,
  serviceErrorType: String?,
) -> String {
  let sendCall =
    if !method.hasInOutParams {
      makeDirectSendCall(
        method: method,
        outputsName: outputsName,
        serviceErrorType: serviceErrorType,
      )
    } else {
      makeInOutSendCall(
        method: method,
        outputsName: outputsName,
        serviceErrorType: serviceErrorType,
      )
    }

  return sendCall
}

private func makeDirectSendCall(
  method: RPCMethod,
  outputsName: String,
  serviceErrorType: String?,
) -> String {
  let serviceErrorArg = makeServiceErrorArg(serviceErrorType)
  return if method.isVoidReturn {
    """
    _ = try await transport.send(
      route: "\(method.route)",
      input: input,
      outputType: \(outputsName).Nothing.self,
    \(serviceErrorArg)
    )
    """
  } else {
    """
    return try await transport.send(
      route: "\(method.route)",
      input: input,
      outputType: \(method.returnType).self,
    \(serviceErrorArg)
    )
    """
  }
}

private func makeInOutSendCall(
  method: RPCMethod,
  outputsName: String,
  serviceErrorType: String?,
) -> String {
  let serviceErrorArg = makeServiceErrorArg(serviceErrorType)
  let outputType = "\(outputsName).\(method.outputTypeName)"
  let mutationAssignments = method.inOutParams
    .map { "\($0.name) = output.mutations.\($0.name)" }
    .joined(separator: "\n")

  return if method.isVoidReturn {
    """
    let output = try await transport.send(
      route: "\(method.route)",
      input: input,
      outputType: \(outputType).self,
    \(serviceErrorArg)
    )
    \(mutationAssignments)
    """
  } else {
    """
    let output = try await transport.send(
      route: "\(method.route)",
      input: input,
      outputType: \(outputType).self,
    \(serviceErrorArg)
    )
    \(mutationAssignments)
    return output.returnValue
    """
  }
}

private func makeServiceErrorArg(_ serviceErrorType: String?) -> String {
  if let serviceErrorType {
    "  serviceErrorType: \(serviceErrorType).self,"
  } else {
    ""
  }
}
