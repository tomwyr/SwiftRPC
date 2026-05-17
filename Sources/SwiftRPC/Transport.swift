import Foundation

/// Default HTTP transport using URLSession.
/// POST /<route>  ->  { "input": ... }  ->  { "ok": ... } | { "error": ... }
public final class HTTPTransport: RPCTransport, Sendable {
  private let baseURL: URL
  private let session: any TransportURLSession
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

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

  public func send<Input: Codable, Output: Codable>(
    route: String,
    input: Input,
    outputType: Output.Type,
  ) async throws -> Output {
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

    let rpcResponse = try decoder.decode(RPCResponse<Output>.self, from: data)

    switch rpcResponse {
    case .success(let output):
      return output
    case .failure(let error):
      throw error
    }
  }
}

/// Protocol for URL session functionality used by transport.
public protocol TransportURLSession: Sendable {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: TransportURLSession {}

/// In-memory transport for running both client and server in the same process.
public final class InMemoryTransport: RPCTransport, RPCHandlerRegistry, @unchecked Sendable {
  private var handlers: [String: (Codable) async throws -> Codable] = [:]

  public init() {}

  public func register<Input: Codable & Sendable, Output: Codable & Sendable>(
    method: String,
    handler: @escaping @Sendable (Input) async throws -> Output
  ) {
    handlers[method] = { input in
      guard let typedInput = input as? Input else {
        throw RPCError(
          code: .internalError,
          message: "Expected type \(Input.self) but got \(type(of: input)) for method \(method)",
        )
      }
      return try await handler(typedInput)
    }
  }

  public func send<Input: Codable, Output: Codable>(
    route: String,
    input: Input,
    outputType: Output.Type,
  ) async throws -> Output {
    // Remove leading "/" from route to match registered method name.
    let method = String(route.dropFirst())

    guard let handler = handlers[method] else {
      throw RPCError(code: .notImplemented, message: "Method not found: \(method)")
    }

    let result = try await handler(input)
    guard let typedOutput = result as? Output else {
      throw RPCError(
        code: .internalError,
        message:
          "Handler returned unexpected type \(type(of: result)), expected \(Output.self) for method \(method)",
      )
    }
    return typedOutput
  }
}
