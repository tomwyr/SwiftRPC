import Foundation
import Hummingbird
import SwiftRPC

@RPC
public protocol EchoRouter: Sendable {
  func ping(message: String) async throws -> String
}

struct EchoRouterServerHandler: EchoRouter {
  func ping(message: String) async throws -> String {
    "Hi"
  }
}
