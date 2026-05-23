import Foundation

@testable import SwiftRPC

@RPC
protocol TestService {
  func logIn(password: String) async throws -> TestActionResult
  func logOut() async throws -> TestActionResult
  func register() async throws -> TestUser
  func unregister(user: TestUser) async throws -> TestActionResult
}

enum TestActionResult: Codable { case success }

struct TestUser: Codable, Equatable {
  let id: UUID
  let name: String
}

struct TestGroup: Codable, Equatable {
  let users: [TestUser]
}
