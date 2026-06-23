import Foundation
import SwiftRPC
import SwiftRPCHummingbird

struct HummingbirdServerExample {
  static func run() async throws {
    print("Hummingbird server starting on http://0.0.0.0:8080")
    try await RPCApplication.hummingbird(hostname: "0.0.0.0", port: 8080) {
      AppServiceServer(handler: AppServiceHandler())
    }.start()
  }
}
