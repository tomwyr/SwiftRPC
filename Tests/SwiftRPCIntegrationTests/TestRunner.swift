import Foundation
import Hummingbird
import Testing

@testable import SwiftRPC
@testable import SwiftRPCHummingbird

let runners: [IntegrationTestRunner] = [
  InMemoryTestRunner(),
  HummingbirdTestRunner(),
]

protocol IntegrationTestRunner: Sendable {
  func run(
    _ server: RPCServer,
    body: @escaping @Sendable (RPCTransport) async throws -> Void,
  ) async throws
}

struct InMemoryTestRunner: IntegrationTestRunner {
  func run(
    _ server: RPCServer,
    body: @escaping @Sendable (RPCTransport) async throws -> Void,
  ) async throws {
    let transport = InMemoryTransport()
    server.register(on: transport)
    try await body(transport)
  }
}

struct HummingbirdTestRunner: IntegrationTestRunner {
  let baseURL = URL(string: "http://127.0.0.1:8080")!

  func run(
    _ server: RPCServer,
    body: @escaping @Sendable (RPCTransport) async throws -> Void,
  ) async throws {
    try await withTestServer(at: baseURL) { router in
      server.register(on: router)
    } body: {
      let transport = HTTPTransport(baseURL: baseURL)
      try await body(transport)
    }
  }
}
