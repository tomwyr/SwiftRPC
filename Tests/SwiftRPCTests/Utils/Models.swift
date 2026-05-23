import Foundation

@testable import SwiftRPC

struct TestUser: Codable, Equatable {
  let id: UUID
  let name: String
}

struct TestGroup: Codable, Equatable {
  let users: [TestUser]
}
