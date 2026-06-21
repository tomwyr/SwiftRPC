import Foundation
import SwiftRPC
import SwiftRPCVapor
import Vapor

struct VaporServerExample {
  static func run() async throws {
    let environment = Environment(
      name: "production",
      arguments: ["SwiftRPCExamples", "serve", "--hostname", "0.0.0.0", "--port", "8080"]
    )
    let app = try await Application.make(environment)

    let server = AppServiceServer(handler: AppServiceHandler())
    server.register(on: app.routes)

    print("Vapor server starting on http://0.0.0.0:8080")
    try await app.execute()
  }
}
