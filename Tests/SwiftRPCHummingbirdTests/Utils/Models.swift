import Foundation

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

struct UpdateProfileInput: Codable, Equatable {
  let userId: UUID
  let email: String
  let age: Int
}

struct UpdateProfileResult: Codable, Equatable {
  let success: Bool
  let updatedAt: String
}

struct UserServiceError: LocalizedError {
  let message: String

  var errorDescription: String? { message }
}

struct UnknownError: Error {}

struct EmptyRequest: Codable, Equatable {}

struct EmptyResponse: Codable, Equatable {}
