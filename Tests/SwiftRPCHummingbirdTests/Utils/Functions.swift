import Foundation
import Hummingbird
import HummingbirdTesting

extension TestClientProtocol {
  func executeRpc(
    uri: String,
    method: HTTPRequest.Method = .post,
    body: Data,
    testCallback: @escaping @Sendable (TestResponse) async throws -> Void
  ) async throws {
    try await execute(
      uri: uri,
      method: method,
      headers: [.contentType: "application/json"],
      body: .init(data: body),
      testCallback: testCallback
    )
  }

  func executeRpc(
    uri: String,
    method: HTTPRequest.Method = .post,
    body: String,
    testCallback: @escaping @Sendable (TestResponse) async throws -> Void
  ) async throws {
    try await execute(
      uri: uri,
      method: method,
      headers: [.contentType: "application/json"],
      body: .init(string: body),
      testCallback: testCallback
    )
  }
}
