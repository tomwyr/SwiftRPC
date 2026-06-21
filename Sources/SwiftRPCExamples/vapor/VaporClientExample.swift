import Foundation
import SwiftRPC

struct VaporClientExample {
  static func run() async throws {
    let client = AppServiceClient(baseURL: URL(string: "http://127.0.0.1:8080")!)
    try await ExampleScenario.run(client: client)
  }
}
