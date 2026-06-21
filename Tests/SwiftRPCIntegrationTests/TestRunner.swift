import Foundation
import Hummingbird
import Testing
import Vapor

@testable import SwiftRPC
@testable import SwiftRPCHummingbird
@testable import SwiftRPCVapor

let runners: [IntegrationTestRunner] = [
  InMemoryTestRunner(),
  HummingbirdTestRunner(),
  VaporTestRunner(),
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
    let registry = InMemoryHandlerRegistry()
    server.register(on: registry)
    let transport = InMemoryTransport(from: registry)
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

struct VaporTestRunner: IntegrationTestRunner {
  let baseURL = URL(string: "http://127.0.0.1:8080")!

  func run(
    _ server: RPCServer,
    body: @escaping @Sendable (RPCTransport) async throws -> Void,
  ) async throws {
    let app = try await Vapor.Application.make(.production)

    do {
      server.register(on: app.routes)
      try await app.server.start(address: .hostname("127.0.0.1", port: 8080))

      let transport = HTTPTransport(baseURL: baseURL)
      try await body(transport)

      await app.server.shutdown()
      try await app.asyncShutdown()
    } catch {
      await app.server.shutdown()
      try? await app.asyncShutdown()
      throw error
    }
  }
}
