import SwiftSyntax

extension RPCMacro {
  static func makeClient(proto: RPCProtocolInfo) throws -> DeclSyntax {
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
}
