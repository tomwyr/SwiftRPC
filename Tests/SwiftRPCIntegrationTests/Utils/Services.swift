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
  func clearCache() async throws
  func updateSettings(
    userId: UserID, notificationsEnabled: Bool?,
    theme: String?, sessionTimeout: Int?,
  ) async throws -> UserSettings
  func getSettings(userId: UserID) async throws -> UserSettings?
}

@RPC
protocol EchoService {
  func ping() async throws -> String
}

@RPC(serviceError: UserError.self)
protocol UserErrorService {
  func authenticate(username: String, password: String) async throws -> AuthToken
}

@RPC(inlineHandler: true)
protocol MovieService {
  func search(query: String) async throws -> Movie
}

@RPC
protocol InOutService {
  func normalize(name: inout String) async throws -> Bool
  func swap(left: inout String, right: inout String) async throws
  func rename(userId: UserID, name: inout String) async throws -> String
  func fail(value: inout String) async throws
}

@RPC(inlineHandler: true)
protocol InlineInOutService {
  func normalize(name: inout String) async throws -> Bool
}

@RPC(varargMaxArity: 3)
protocol LogService {
  func collect(prefix: String, messages: String...) async throws -> [String]
}

@RPC(varargMaxArity: 2, varargOverflowBehavior: .truncate)
protocol TruncatingLogService {
  func collect(messages: String...) async throws -> [String]
}

@RPC(inlineHandler: true, varargMaxArity: 2)
protocol InlineLogService {
  func collect(messages: String...) async throws -> [String]
}

@RPC(varargMaxArity: 32)
protocol MaxArityLogService {
  func count(messages: String...) async throws -> Int
}
