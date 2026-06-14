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
