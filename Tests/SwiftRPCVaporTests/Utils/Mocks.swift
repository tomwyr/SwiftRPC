@testable import SwiftRPC

struct MockEchoService: EchoService {
  let result: String

  func echo(message: String) async throws -> String {
    result
  }
}
