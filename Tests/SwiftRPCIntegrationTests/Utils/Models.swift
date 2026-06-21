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

enum UserError: RPCMethodError, Equatable {
  case invalidCredentials
  case profileNotFound
  case updateFailed
  case unknown

  static func fromRPC(_ error: RPCError) -> Self {
    .unknown
  }
}

enum PasswordError: RPCServiceError, Equatable {
  case expiredToken
}

struct UnexpectedError: Error {}

struct ThrowingTransport: RPCTransport {
  enum Failure: Sendable {
    case rpc(RPCError)
    case unexpected
  }

  let failure: Failure

  func send<Input: Codable, Output: Codable>(
    route: String,
    input: Input,
    outputType: Output.Type,
  ) async throws -> Output {
    switch failure {
    case .rpc(let error):
      throw error
    case .unexpected:
      throw UnexpectedError()
    }
  }
}

struct Movie: Codable, Equatable {
  let title: String
  let duration: Int
}
