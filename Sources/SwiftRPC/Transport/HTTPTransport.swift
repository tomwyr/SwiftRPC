import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Default HTTP transport using URLSession.
/// POST /<route>  ->  { "input": ... }  ->  { "ok": ... } | { "error": ... }
public final class HTTPTransport: RPCTransport, Sendable {
  private let baseURL: URL
  private let session: any TransportURLSession
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  /// Creates an HTTP transport.
  public init(
    baseURL: URL,
    session: any TransportURLSession = URLSession.shared,
    encoder: JSONEncoder = JSONEncoder(),
    decoder: JSONDecoder = JSONDecoder(),
  ) {
    self.baseURL = baseURL
    self.session = session
    self.encoder = encoder
    self.decoder = decoder
  }

  /// Sends an RPC request over HTTP and returns the decoded result.
  public func send<Input: Codable, Output: Codable>(
    route: String,
    input: Input,
    outputType: Output.Type,
  ) async throws -> Output {
    let data = try await sendRequest(route: route, input: input)
    let response = try decoder.decode(RPCResponse<Output>.self, from: data)

    switch response {
    case .success(let output):
      return output
    case .failure(.core(let error)):
      throw error
    case .failure(.service(let error)):
      throw error
    }
  }

  /// Sends an RPC request over HTTP that may return a typed service-defined error.
  public func send<Input: Codable, Output: Codable, ServiceError: RPCServiceError>(
    route: String,
    input: Input,
    outputType: Output.Type,
    serviceErrorType: ServiceError.Type,
  ) async throws -> Output {
    let data = try await sendRequest(route: route, input: input)
    let response = try decoder.decode(RPCTypedResponse<Output, ServiceError>.self, from: data)

    switch response {
    case .success(let output):
      return output
    case .failure(.core(let error)):
      throw error
    case .failure(.service(let error)):
      throw error
    }
  }

  private func sendRequest<Input: Codable>(
    route: String,
    input: Input
  ) async throws -> Data {
    let url = baseURL.appending(path: route)
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let envelope = RPCRequest(input: input)
    request.httpBody = try encoder.encode(envelope)

    let (data, response) = try await session.data(for: request)

    guard let http = response as? HTTPURLResponse else {
      throw RPCError(code: .internalError, message: "Non-HTTP response")
    }

    if http.statusCode == 401 {
      throw RPCError(code: .unauthorized, message: "Unauthorized")
    }

    return data
  }
}

/// Protocol for URL session functionality used by transport.
public protocol TransportURLSession: Sendable {
  /// Loads data for a URL request.
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

#if canImport(FoundationNetworking)
  extension URLSession: TransportURLSession {
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      try await data(for: request, delegate: nil)
    }
  }
#else
  extension URLSession: TransportURLSession {}
#endif
