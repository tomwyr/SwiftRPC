import Foundation

/// The envelope sent from client → server for every RPC call.
public struct RPCRequest<Input: Codable>: Codable {
  public let input: Input

  public init(input: Input) {
    self.input = input
  }
}

/// The envelope returned from server → client.
public enum RPCResponse<Output: Codable>: Codable {
  case success(Output)
  case failure(RPCError)

  enum CodingKeys: String, CodingKey {
    case ok, error
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let output = try container.decodeIfPresent(Output.self, forKey: .ok) {
      self = .success(output)
    } else {
      let error = try container.decode(RPCError.self, forKey: .error)
      self = .failure(error)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .success(let output):
      try container.encode(output, forKey: .ok)
    case .failure(let error):
      try container.encode(error, forKey: .error)
    }
  }
}

/// A serialisable RPC error propagated across the wire.
public struct RPCError: Error, LocalizedError, Codable, Sendable {
  public let code: RPCErrorCode
  public let message: String

  public init(code: RPCErrorCode, message: String) {
    self.code = code
    self.message = message
  }

  public var errorDescription: String? {
    "[\(code.rawValue)] \(message)"
  }
}

/// Standard error codes for RPC failures.
public enum RPCErrorCode: String, Codable, Sendable {
  case notFound = "NOT_FOUND"
  case badRequest = "BAD_REQUEST"
  case unauthorized = "UNAUTHORIZED"
  case internalError = "INTERNAL_ERROR"
}

/// Implemented by the generated client. Not used directly.
public protocol RPCTransport: Sendable {
  func send<Input: Codable, Output: Codable>(
    route: String,
    input: Input,
    outputType: Output.Type,
  ) async throws -> Output
}

/// Registering RPC handlers with a transport.
/// Each transport provides its own implementation of the protocol.
public protocol RPCHandlerRegistry: Sendable {
  func register<Input: Codable & Sendable, Output: Codable & Sendable>(
    method: String,
    handler: @escaping @Sendable (Input) async throws -> Output
  )
}

/// Core protocol for generated RPC servers.
/// Transport packages can extend this protocol to provide convenience registration methods.
public protocol RPCServer: Sendable {
  func register(on registry: any RPCHandlerRegistry)
}
