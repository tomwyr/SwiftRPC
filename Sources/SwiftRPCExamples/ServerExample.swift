import Foundation
import Hummingbird
import SwiftRPC
import SwiftRPCHummingbird

struct ServerApp {
  static func run() async throws {
    let router = Router()

    let server = AppRouterServer(handler: AppRouterHandler())
    server.register(on: router)

    let app = Application(
      router: router,
      configuration: .init(address: .hostname("0.0.0.0", port: 8080)),
    )

    print("Server starting on http://0.0.0.0:8080")
    try await app.runService()
  }
}
