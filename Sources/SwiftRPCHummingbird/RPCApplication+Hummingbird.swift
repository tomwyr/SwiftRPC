import Hummingbird
import SwiftRPC

/// Hummingbird-backed RPC application for RPC-only servers.
public struct RPCHummingbirdApplication {
  let hostname: String
  let port: Int
  let servers: [any RPCServer]

  /// Starts the Hummingbird application and waits for shutdown.
  public func start() async throws {
    let router = makeRouter()
    let app = Application(
      router: router,
      configuration: .init(address: .hostname(hostname, port: port)),
    )
    try await app.runService()
  }

  private func makeRouter() -> Router<BasicRequestContext> {
    let router = Router()
    for server in servers {
      server.register(on: router)
    }
    return router
  }
}

extension RPCApplication {
  /// Creates a Hummingbird-backed RPC application from generated servers.
  public static func hummingbird(
    hostname: String,
    port: Int,
    @RPCServerBuilder _ servers: () -> [any RPCServer]
  ) -> RPCHummingbirdApplication {
    RPCHummingbirdApplication(hostname: hostname, port: port, servers: servers())
  }
}
