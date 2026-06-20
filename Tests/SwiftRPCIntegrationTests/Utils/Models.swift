import Foundation

@testable import SwiftRPC

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
  let sessionTimeout: Int
}

struct LogoutResponse: Codable, Equatable {
  let success: Bool
  let message: String
}

enum UserError: RPCServiceError, Equatable {
  case invalidCredentials
  case profileNotFound
  case updateFailed
}

enum PasswordError: RPCServiceError, Equatable {
  case expiredToken
}

struct UnexpectedError: Error {}

struct Movie: Codable, Equatable {
  let title: String
  let duration: Int
}
