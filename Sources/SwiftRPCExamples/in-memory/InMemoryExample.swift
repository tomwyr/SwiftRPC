import Foundation
import SwiftRPC

struct InMemoryApp {
  static func run() async throws {
    let registry = InMemoryHandlerRegistry()
    let server = AppServiceServer(handler: AppServiceHandler())
    server.register(on: registry)

    let transport = InMemoryTransport(from: registry)
    let client = AppServiceClient(transport: transport)

    print("In-memory client-server running\n")
    try await ExampleScenario.run(client: client)
  }
}
