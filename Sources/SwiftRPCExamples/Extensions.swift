import Foundation
import Hummingbird
import SwiftRPC

extension Response {
  /// Encode an RPCResponse envelope as a JSON HTTP response.
  static func json<T: Codable>(
    _ value: RPCResponse<T>,
    encoder: JSONEncoder,
    status: HTTPResponse.Status = .ok,
  ) throws -> Response {
    let data = try encoder.encode(value)
    var headers = HTTPFields()
    headers[.contentType] = "application/json"
    return Response(
      status: status,
      headers: headers,
      body: .init(byteBuffer: .init(data: data)),
    )
  }
}

extension Request {
  /// Decode the full request body as a `Decodable` type using the provided decoder.
  func decode<T: Decodable>(as type: T.Type, using decoder: JSONDecoder) async throws -> T {
    let buffer = try await body.collect(upTo: .max)
    return try decoder.decode(type, from: Data(buffer.readableBytesView))
  }
}
