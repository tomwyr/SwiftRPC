import Foundation

@testable import SwiftRPC

class MockUserService: UserService, @unchecked Sendable {
  var loginCalls = 0
  var loginUsernames = [String]()
  var shouldFailLogin = false
  var customLoginError: RPCError?
  var loginResult: AuthToken?

  var logoutCalls = 0
  var logoutResult: LogoutResponse?

  var registerCalls = 0
  var registerResult: UserID?

  var getProfileCalls = 0
  var getProfileUserIds = [UserID]()
  var profile: UserProfile?

  var searchUsersCalls = 0
  var searchResults = [UserProfile]()

  var validateSessionCalls = 0
  var validateSessionResult: Bool?

  var batchDeleteUserIdsCalls = 0
  var batchDeleteUserIdsResult: Int?

  var upgradeAccountCalls = 0
  var upgradeAccountUserIds = [UserID]()
  var upgradedAccountTypes = [AccountType]()
  var upgradeAccountResult: Bool?

  var getAccountTypeCalls = 0
  var getAccountTypeUserIds = [UserID]()
  var getAccountTypeResult: AccountType?

  var pingCalls = 0
  var pingResult: String?

  var clearCacheCalls = 0

  func login(username: String, password: String) async throws -> AuthToken {
    loginCalls += 1
    loginUsernames.append(username)

    if let customError = customLoginError {
      throw customError
    }

    if shouldFailLogin {
      throw ServiceError.invalidCredentials
    }

    guard let result = loginResult else {
      throw ServiceError.profileNotFound
    }
    return result
  }

  func logout(token: AuthToken) async throws -> LogoutResponse {
    logoutCalls += 1
    guard let result = logoutResult else {
      throw ServiceError.updateFailed
    }
    return result
  }

  func register(email: String, password: String, profile: UserProfile) async throws -> UserID {
    registerCalls += 1
    guard let result = registerResult else {
      throw ServiceError.updateFailed
    }
    return result
  }

  func getProfile(userId: UserID) async throws -> UserProfile {
    getProfileCalls += 1
    getProfileUserIds.append(userId)

    guard let profile = profile else {
      throw ServiceError.profileNotFound
    }

    return profile
  }

  func searchUsers(query: String, limit: Int) async throws -> [UserProfile] {
    searchUsersCalls += 1
    return searchResults
  }

  func validateSession() async throws -> Bool {
    validateSessionCalls += 1
    guard let result = validateSessionResult else {
      throw ServiceError.updateFailed
    }
    return result
  }

  func batchDeleteUserIds(userIds: [UserID]) async throws -> Int {
    batchDeleteUserIdsCalls += 1
    guard let result = batchDeleteUserIdsResult else {
      throw ServiceError.updateFailed
    }
    return result
  }

  func upgradeAccount(userId: UserID, newType: AccountType) async throws -> Bool {
    upgradeAccountCalls += 1
    upgradeAccountUserIds.append(userId)
    upgradedAccountTypes.append(newType)
    guard let result = upgradeAccountResult else {
      throw ServiceError.updateFailed
    }
    return result
  }

  func getAccountType(userId: UserID) async throws -> AccountType {
    getAccountTypeCalls += 1
    getAccountTypeUserIds.append(userId)
    guard let result = getAccountTypeResult else {
      throw ServiceError.updateFailed
    }
    return result
  }

  func ping() async throws -> String {
    pingCalls += 1
    guard let result = pingResult else {
      throw ServiceError.updateFailed
    }
    return result
  }

  func clearCache() async throws {
    clearCacheCalls += 1
  }
}
