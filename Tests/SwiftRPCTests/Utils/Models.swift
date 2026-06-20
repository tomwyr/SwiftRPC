import Foundation

@testable import SwiftRPC

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

enum UserError: RPCServiceError, Equatable {
  case rejected(reason: String)
}
