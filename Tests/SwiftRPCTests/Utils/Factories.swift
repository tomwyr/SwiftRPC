import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@testable import SwiftRPC

func makeResponse(for request: URLRequest, status: Int) -> HTTPURLResponse {
  HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
}

func makeGenericResponse(for request: URLRequest) -> URLResponse {
  URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
}

func rpcEncode<Output: Codable>(_ response: RPCResponse<Output>) throws -> Data {
  try JSONEncoder().encode(response)
}

func rpcDecode<Input: Codable>(
  _ request: URLRequest, into: Input.Type = Input.self,
) throws -> RPCRequest<Input> {
  try JSONDecoder().decode(RPCRequest<Input>.self, from: request.httpBody!)
}

func makeHTTPTransport(baseURL: String, session: TransportURLSession) -> HTTPTransport {
  HTTPTransport(
    baseURL: URL(string: baseURL)!,
    session: session,
  )
}
