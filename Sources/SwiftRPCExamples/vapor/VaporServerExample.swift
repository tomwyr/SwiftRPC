import Foundation
import SwiftRPC
import SwiftRPCVapor

struct VaporServerExample {
  static func run() async throws {
    print("Vapor server starting on http://0.0.0.0:8080")
    try await RPCApplication.vapor(hostname: "0.0.0.0", port: 8080) {
      AppServiceServer(handler: AppServiceHandler())
    }.start()
  }
}
