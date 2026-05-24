import Foundation

@testable import SwiftRPC

@RPC
protocol UserService {
  func login(username: String, password: String) async throws -> AuthToken
  func logout(token: AuthToken) async throws -> LogoutResponse
  func register(email: String, password: String, profile: UserProfile) async throws -> UserID
  func getProfile(userId: UserID) async throws -> UserProfile
  func searchUsers(query: String, limit: Int) async throws -> [UserProfile]
  func validateSession() async throws -> Bool
  func batchDeleteUserIds(userIds: [UserID]) async throws -> Int
  func upgradeAccount(userId: UserID, newType: AccountType) async throws -> Bool
  func getAccountType(userId: UserID) async throws -> AccountType
  func ping() async throws -> String
  func clearCache() async throws
}

struct AuthToken: Codable, Equatable {
  let token: String
  let expiresAt: Int
}

typealias UserID = String

enum AccountType: String, Codable, Equatable {
  case standard
  case premium
  case enterprise
}

struct UserProfile: Codable, Equatable {
  let userId: UserID
  let email: String
  let fullName: String
  let settings: UserSettings
  let accountType: AccountType
}

struct UserSettings: Codable, Equatable {
  let notificationsEnabled: Bool
  let theme: String
  let language: String
}

struct LogoutResponse: Codable, Equatable {
  let success: Bool
  let message: String
}

enum ServiceError: Error {
  case invalidCredentials
  case profileNotFound
  case updateFailed
}
