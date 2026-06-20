import Foundation

/// The envelope sent from client → server for every RPC call.
public struct RPCRequest<Input: Codable>: Codable {
  /// The method input payload.
  public let input: Input

  /// Creates an RPC request envelope.
  public init(input: Input) {
    self.input = input
  }
}

/// The envelope returned from server → client.
public enum RPCResponse<Output: Codable>: Codable {
  /// A successful RPC result.
  case success(Output)

  /// A failed RPC result.
  case failure(RPCResponseError)
}

/// Decoding helper for RPC responses with a known service-defined error type.
enum RPCTypedResponse<Output: Codable, ServiceError: RPCServiceError>: Decodable {
  /// A successful RPC result.
  case success(Output)

  /// A failed RPC result with either an RPC error or the declared service error type.
  case failure(RPCTypedResponseError<ServiceError>)
}

/// A failure reported by the RPC layer.
public struct RPCError: Error, LocalizedError, Codable, Sendable {
  /// The kind of failure that occurred.
  public let code: RPCErrorCode

  /// A human-readable description of the failure.
  public let message: String

  /// Creates an RPC error.
  public init(code: RPCErrorCode, message: String) {
    self.code = code
    self.message = message
  }

  /// A localized description of the failure.
  public var errorDescription: String? {
    "[\(code.rawValue)] \(message)"
  }
}

/// A service-defined error that can be transported through RPC failures.
public protocol RPCServiceError: Error, Codable, Sendable {}

/// A typed RPC failure with either an RPC-layer error or a service-defined error.
public enum RPCFailure<ServiceError: RPCServiceError>: Error, Sendable {
  /// A failure reported by the RPC layer.
  case rpc(RPCError)

  /// A service-defined failure.
  case service(ServiceError)
}

/// A service-defined error transported through RPC.
public struct RPCServiceErrorEnvelope: Error, Sendable {
  let error: any RPCServiceError

  /// Creates a service error envelope.
  public init(_ error: some RPCServiceError) {
    self.error = error
  }
}

extension RPCServiceErrorEnvelope {
  func unwrap<ServiceError: RPCServiceError>(
    as type: ServiceError.Type = ServiceError.self
  ) throws -> ServiceError {
    guard let serviceError = error as? ServiceError else {
      throw RPCError(
        code: .internalError,
        message: "Expected service error \(ServiceError.self) but got \(Swift.type(of: error))",
      )
    }
    return serviceError
  }
}

/// A failure returned in an RPC response.
public enum RPCResponseError: Error, Codable, Sendable {
  /// An RPC failure.
  case rpc(RPCError)

  /// A service-defined failure.
  case service(RPCServiceErrorEnvelope)
}

/// Standard error codes for RPC failures.
public enum RPCErrorCode: String, Codable, Sendable {
  /// The requested resource or method was not found.
  case notFound = "NOT_FOUND"

  /// The request was malformed or failed validation.
  case badRequest = "BAD_REQUEST"

  /// The request was not authorized.
  case unauthorized = "UNAUTHORIZED"

  /// The request failed because of an internal server error.
  case internalError = "INTERNAL_ERROR"
}

/// Implemented by the generated client. Not used directly.
public protocol RPCTransport: Sendable {
  /// Sends an RPC request and returns the decoded result.
  func send<Input: Codable, Output: Codable>(
    route: String,
    input: Input,
    outputType: Output.Type,
  ) async throws -> Output

  /// Sends an RPC request that may return a typed service-defined error.
  func send<Input: Codable, Output: Codable, ServiceError: RPCServiceError>(
    route: String,
    input: Input,
    outputType: Output.Type,
    serviceErrorType: ServiceError.Type,
  ) async throws -> Output
}

extension RPCTransport {
  /// Sends an RPC request that may return a typed service-defined error.
  ///
  /// Custom transports can rely on this default implementation when they already
  /// throw `RPCServiceErrorEnvelope` values from the untyped `send` method.
  public func send<Input: Codable, Output: Codable, ServiceError: RPCServiceError>(
    route: String,
    input: Input,
    outputType: Output.Type,
    serviceErrorType: ServiceError.Type,
  ) async throws -> Output {
    do {
      return try await send(route: route, input: input, outputType: outputType)
    } catch let serviceError as RPCServiceErrorEnvelope {
      throw try serviceError.unwrap(as: serviceErrorType)
    }
  }
}

/// Registering RPC handlers with a transport.
/// Each transport provides its own implementation of the protocol.
public protocol RPCHandlerRegistry {
  /// Registers a handler for an RPC method name.
  func register<Input: Codable & Sendable, Output: Codable & Sendable>(
    method: String,
    handler: @escaping @Sendable (Input) async throws -> Output
  )
}

/// Core protocol for generated RPC servers.
/// Transport packages can extend this protocol to provide convenience registration methods.
public protocol RPCServer: Sendable {
  /// Registers this server's methods on a handler registry.
  func register(on registry: any RPCHandlerRegistry)
}
