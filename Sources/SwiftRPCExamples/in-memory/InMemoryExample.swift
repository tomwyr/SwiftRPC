import Foundation
import SwiftRPC

struct InMemoryApp {
  static func run() async throws {
    let client = RPCApplication.inMemory {
      AppServiceServer(handler: AppServiceHandler())
    }.bind(AppServiceClient.self)

    print("In-memory client-server running\n")
    try await ExampleScenario.run(client: client)
  }
}
