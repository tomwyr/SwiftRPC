import Foundation

@testable import SwiftRPC

@RPC
protocol UserService {
  func logIn(password: String) async throws -> UserActionResult
  func logOut() async throws -> Int
  func create() async throws -> UserProfile
  func delete(user: UserProfile) async throws -> Bool
}

enum UserActionResult: Codable { case success }

struct UserProfile: Codable, Equatable {
  let userId: UUID
  let fullName: String
  let accountSettings: AccountSettings
  let accountTypes: [AccountType]
}

struct AccountSettings: Codable, Equatable {
  let privateProfile: Bool
  let maxFollowers: Int
  let contentLanguage: String
}

enum AccountType: String, Codable, Equatable {
  case standard
  case premium
  case enterprise
}
