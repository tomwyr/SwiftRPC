import Foundation

extension RPCResponse {
  enum CodingKeys: String, CodingKey {
    case ok, error
  }

  /// Decodes an RPC response from its transport envelope.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self = try container.decodeRPCResponseEnvelope(
      success: RPCResponse.success,
      failure: { .failure(try RPCResponseError(from: $0)) }
    )
  }

  /// Encodes an RPC response into its transport envelope.
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

extension RPCResponseError {
  /// Decodes an RPC response error.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: RPCResponseErrorCodingKeys.self)
    let type = try container.decodeResponseErrorType()

    switch type {
    case .rpc:
      self = .rpc(try container.decodeRPCError())
    case .service:
      throw DecodingError.dataCorruptedError(
        forKey: .payload,
        in: container,
        debugDescription: "Cannot decode service error without a service error type"
      )
    }
  }

  /// Encodes an RPC response error.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: RPCResponseErrorCodingKeys.self)

    switch self {
    case .rpc(let error):
      try container.encode(RPCResponseErrorType.rpc, forKey: .type)
      try container.encode(error.code, forKey: .code)
      try container.encode(error.message, forKey: .message)
    case .service(let failure):
      try container.encode(RPCResponseErrorType.service, forKey: .type)
      try failure.error.encode(to: container.superEncoder(forKey: .payload))
    }
  }
}

extension RPCTypedResponse {
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: RPCResponse<Output>.CodingKeys.self)
    self = try container.decodeRPCResponseEnvelope(
      success: RPCTypedResponse.success,
      failure: { .failure(try RPCTypedResponseError<ServiceError>(from: $0)) },
    )
  }
}

/// Decoding helper for RPC failures with a known service-defined error type.
enum RPCTypedResponseError<ServiceError: RPCServiceError>: Decodable {
  /// An RPC failure.
  case rpc(RPCError)

  /// A service-defined failure decoded as the declared service error type.
  case service(ServiceError)

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: RPCResponseErrorCodingKeys.self)
    let type = try container.decodeResponseErrorType()

    switch type {
    case .rpc:
      self = .rpc(try container.decodeRPCError())
    case .service:
      let error = try ServiceError(from: container.superDecoder(forKey: .payload))
      self = .service(error)
    }
  }
}

private enum RPCResponseErrorCodingKeys: String, CodingKey {
  case type
  case code
  case message
  case payload
}

private enum RPCResponseErrorType: String, Codable, Sendable {
  case rpc
  case service
}

extension KeyedDecodingContainer {
  fileprivate func decodeRPCResponseEnvelope<Output: Codable, Response>(
    success: (Output) -> Response,
    failure: (Decoder) throws -> Response,
  ) throws -> Response where Key == RPCResponse<Output>.CodingKeys {
    if contains(.ok) {
      let output = try decode(Output.self, forKey: .ok)
      return success(output)
    } else if contains(.error) {
      return try failure(superDecoder(forKey: .error))
    } else {
      throw DecodingError.dataCorruptedError(
        forKey: .ok,
        in: self,
        debugDescription: "Expected either 'ok' or 'error' key, but neither was found"
      )
    }
  }
}

extension KeyedDecodingContainer where Key == RPCResponseErrorCodingKeys {
  fileprivate func decodeResponseErrorType() throws -> RPCResponseErrorType {
    if contains(.type) {
      try decode(RPCResponseErrorType.self, forKey: .type)
    } else {
      throw DecodingError.dataCorruptedError(
        forKey: .type,
        in: self,
        debugDescription: "Expected 'type' key for RPC response error"
      )
    }

  }

  fileprivate func decodeRPCError() throws -> RPCError {
    let code = try decode(RPCErrorCode.self, forKey: .code)
    let message = try decode(String.self, forKey: .message)
    return RPCError(code: code, message: message)
  }
}
