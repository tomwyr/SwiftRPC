/// Namespace for convenience RPC application factories.
public enum RPCApplication {}

/// In-memory RPC application for binding generated clients to local handlers.
public struct RPCInMemoryApplication {
  private let registry: InMemoryHandlerRegistry

  init(servers: [any RPCServer]) {
    let registry = InMemoryHandlerRegistry()
    for server in servers {
      server.register(on: registry)
    }
    self.registry = registry
  }

  /// Creates a generated client connected to this in-memory application.
  public func bind<Client: RPCClient>(_ client: Client.Type) -> Client {
    Client(transport: InMemoryTransport(from: registry))
  }
}

extension RPCApplication {
  /// Creates an in-memory RPC application from generated servers.
  public static func inMemory(
    @RPCServerBuilder _ servers: () -> [any RPCServer]
  ) -> RPCInMemoryApplication {
    RPCInMemoryApplication(servers: servers())
  }
}

/// Builds a list of generated RPC servers for an RPC application.
@resultBuilder
public enum RPCServerBuilder {
  public static func buildExpression(_ server: any RPCServer) -> [any RPCServer] {
    [server]
  }

  public static func buildBlock(_ components: [any RPCServer]...) -> [any RPCServer] {
    components.flatMap { $0 }
  }

  public static func buildOptional(_ component: [any RPCServer]?) -> [any RPCServer] {
    component ?? []
  }

  public static func buildEither(first component: [any RPCServer]) -> [any RPCServer] {
    component
  }

  public static func buildEither(second component: [any RPCServer]) -> [any RPCServer] {
    component
  }

  public static func buildArray(_ components: [[any RPCServer]]) -> [any RPCServer] {
    components.flatMap { $0 }
  }
}
