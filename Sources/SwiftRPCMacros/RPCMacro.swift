import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct RPCMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext,
  ) throws -> [DeclSyntax] {
    guard let proto = declaration.as(ProtocolDeclSyntax.self) else {
      throw RPCMacroError.notAProtocol
    }

    let methods = try proto.memberBlock.members.compactMap { member -> RPCMethod? in
      guard let fn = member.decl.as(FunctionDeclSyntax.self) else { return nil }
      return try RPCMethod(from: fn)
    }

    let protoName = proto.name.text

    let inputsDecl = try makeInputTypes(protoName: protoName, methods: methods)
    let clientDecl = try makeClient(protoName: protoName, methods: methods)
    let serverDecl = try makeServer(protoName: protoName, methods: methods)

    return [inputsDecl, clientDecl, serverDecl]
  }
}

struct RPCMethod {
  let name: String
  let params: [(label: String, name: String, type: String)]
  let returnType: String

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

    guard let fnReturnType = fn.signature.returnClause?.type.trimmedDescription else {
      throw RPCMacroError.methodMustReturnValue(name: fn.name.text)
    }
    returnType = fnReturnType
  }

  /// The internal input struct name, e.g. `GetUser`
  var inputTypeName: String {
    "\(name.prefix(1).uppercased())\(name.dropFirst())"
  }

  /// The route path, e.g. `/getUser`
  var route: String { "/\(name)" }
}

private func makeInputTypes(protoName: String, methods: [RPCMethod]) throws -> DeclSyntax {
  let structName = "\(protoName)Inputs"

  var memberDecls = [String]()

  for method in methods {
    if method.params.isEmpty {
      memberDecls.append("  struct \(method.inputTypeName): Codable {}")
    } else {
      let fields = method.params
        .map { "  let \($0.name): \($0.type)" }
        .joined(separator: "\n")

      memberDecls.append(
        """
        struct \(method.inputTypeName): Codable {
        \(fields)
        }
        """.indented())
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

private func makeClient(protoName: String, methods: [RPCMethod]) throws -> DeclSyntax {
  let clientName = "\(protoName)Client"

  var methodDecls = [String]()

  for method in methods {
    let inputTypeName = "\(protoName)Inputs.\(method.inputTypeName)"

    let paramList = method.params
      .map { "\($0.label): \($0.type)" }
      .joined(separator: ", ")
    let inputInit = method.params
      .map { "\($0.name): \($0.name)" }
      .joined(separator: ", ")

    let methodBody = """
      func \(method.name)(\(paramList)) async throws -> \(method.returnType) {
        let input = \(inputTypeName)(\(inputInit))
        return try await transport.send(
          route: "\(method.route)",
          input: input,
          outputType: \(method.returnType).self
        )
      }
      """
    methodDecls.append(methodBody)
  }

  let allMethods = methodDecls.map { $0.indented() }.joined(separator: "\n\n")

  let source = """
    struct \(clientName): Sendable {
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

private func makeServer(protoName: String, methods: [RPCMethod]) throws -> DeclSyntax {
  let serverName = "\(protoName)Server"

  var methodRegistrations = [String]()

  for method in methods {
    // Argument forwarding: handler.getUser(id: input.id, ...)
    let callArgs = method.params
      .map { "\($0.label): input.\($0.name)" }
      .joined(separator: ", ")

    let registration = """
      registry.register(method: "\(method.name)") { (input: \(protoName)Inputs.\(method.inputTypeName)) in
        try await self.handler.\(method.name)(\(callArgs))
      }
      """
    methodRegistrations.append(registration)
  }

  let allMethods = methodRegistrations.map { $0.indented(width: 4) }.joined(separator: "\n\n")

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

enum RPCMacroError: Error, CustomStringConvertible {
  case notAProtocol
  case methodMustBeAsyncThrows(name: String)
  case methodMustReturnValue(name: String)

  var description: String {
    switch self {
    case .notAProtocol:
      "@RPC can only be applied to a protocol"
    case .methodMustBeAsyncThrows(let name):
      "@RPC: '\(name)' must be declared 'async throws'"
    case .methodMustReturnValue(let name):
      "@RPC: '\(name)' must have a return type"
    }
  }
}

extension String {
  fileprivate func indented(width: Int = 2) -> String {
    let spaces = String(repeating: " ", count: width)
    return split(separator: "\n").map { spaces + $0 }.joined(separator: "\n")
  }
}
