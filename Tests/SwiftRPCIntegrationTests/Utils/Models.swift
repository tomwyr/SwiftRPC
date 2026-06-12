import Foundation

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

enum ServiceError: Error {
  case invalidCredentials
  case profileNotFound
  case updateFailed
}
