import SwiftDiagnostics

enum RPCMacroError: Error, CustomStringConvertible {
  case notAProtocol
  case associatedTypesAreUnsupported(name: String)
  case genericMethod(name: String)
  case overloadedMethod(name: String)
  case inOutParameter(name: String)
  case methodMustBeAsyncThrows(name: String)
  case parameterTypeMustBeCodable(name: String)
  case returnTypeMustBeCodable(name: String)
  case variadicParameter(name: String)

  var description: String {
    switch self {
    case .notAProtocol:
      "@RPC can only be applied to a protocol"
    case .associatedTypesAreUnsupported(let name):
      "@RPC: associated type '\(name)' is not supported"
    case .genericMethod(let name):
      "@RPC: '\(name)' must not be generic"
    case .overloadedMethod(let name):
      "@RPC: overloaded method '\(name)' is not supported"
    case .inOutParameter(let name):
      "@RPC: parameter '\(name)' must not be inout"
    case .methodMustBeAsyncThrows(let name):
      "@RPC: '\(name)' must be declared 'async throws'"
    case .parameterTypeMustBeCodable(let name):
      "@RPC: parameter '\(name)' must use a Codable-compatible type"
    case .returnTypeMustBeCodable(let name):
      "@RPC: return type of '\(name)' must be Codable-compatible"
    case .variadicParameter(let name):
      "@RPC: parameter '\(name)' must not be variadic"
    }
  }
}

extension RPCMacroError: DiagnosticMessage {
  var message: String {
    description
  }

  var diagnosticID: MessageID {
    let errorName = String(describing: self).replacing(/\(.*/, with: "")
    return MessageID(domain: "SwiftRPCMacros", id: errorName)
  }

  var severity: DiagnosticSeverity {
    .error
  }
}
