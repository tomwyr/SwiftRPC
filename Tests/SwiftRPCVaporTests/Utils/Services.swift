import Foundation
import SwiftRPC

@RPC
protocol EchoService {
  func echo(message: String) async throws -> String
}
