import SwiftRPC
import Vapor

/// Vapor-backed RPC application for RPC-only servers.
public struct RPCVaporApplication {
  let hostname: String
  let port: Int
  let environment: Environment
  let servers: [any RPCServer]

  /// Starts the Vapor application and waits for shutdown.
  public func start() async throws {
    let app = try await makeApplication()

    do {
      try await app.execute()
      try await app.asyncShutdown()
    } catch {
      try? await app.asyncShutdown()
      throw error
    }
  }

  private func makeApplication() async throws -> Application {
    let app = try await Application.make(environment)
    app.http.server.configuration.hostname = hostname
    app.http.server.configuration.port = port
    register(on: app.routes)
    return app
  }

  private func register(on routes: any RoutesBuilder) {
    for server in servers {
      server.register(on: routes)
    }
  }
}

extension RPCApplication {
  /// Creates a Vapor-backed RPC application from generated servers.
  public static func vapor(
    hostname: String,
    port: Int,
    environment: Environment = .production,
    @RPCServerBuilder _ servers: () -> [any RPCServer]
  ) -> RPCVaporApplication {
    RPCVaporApplication(
      hostname: hostname,
      port: port,
      environment: environment,
      servers: servers(),
    )
  }
}
