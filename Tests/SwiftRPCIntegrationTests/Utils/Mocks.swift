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

  var clearCacheCalls = 0

  var updateSettingsCalls = 0
  var updateSettingsUserIds = [UserID]()
  var updateSettingsNotificationsEnabled = [Bool?]()
  var updateSettingsThemes = [String?]()
  var updateSettingsSessionTimeouts = [Int?]()
  var updateSettingsResult: UserSettings?

  var getSettingsCalls = 0
  var getSettingsUserIds = [UserID]()
  var settings: UserSettings?

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

  func clearCache() async throws {
    clearCacheCalls += 1
  }

  func updateSettings(
    userId: UserID,
    notificationsEnabled: Bool?,
    theme: String?,
    sessionTimeout: Int?
  ) async throws -> UserSettings {
    updateSettingsCalls += 1
    updateSettingsUserIds.append(userId)
    updateSettingsNotificationsEnabled.append(notificationsEnabled)
    updateSettingsThemes.append(theme)
    updateSettingsSessionTimeouts.append(sessionTimeout)

    guard let result = updateSettingsResult else {
      throw ServiceError.updateFailed
    }

    return result
  }

  func getSettings(userId: UserID) async throws -> UserSettings? {
    getSettingsCalls += 1
    getSettingsUserIds.append(userId)

    return settings
  }
}

class MockEchoService: EchoService, @unchecked Sendable {
  var pingCalls = 0
  var pingResult: String?

  func ping() async throws -> String {
    pingCalls += 1
    guard let result = pingResult else {
      throw ServiceError.updateFailed
    }
    return result
  }
}

class MockLogService: LogService, @unchecked Sendable {
  var collectCalls = 0
  var collectedPrefixes = [String]()
  var collectedMessages = [[String]]()

  func collect(prefix: String, messages: String...) async throws -> [String] {
    collectCalls += 1
    collectedPrefixes.append(prefix)
    collectedMessages.append(messages)
    return [prefix] + messages
  }
}

class MockTruncatingLogService: TruncatingLogService, @unchecked Sendable {
  var collectCalls = 0
  var collectedMessages = [[String]]()

  func collect(messages: String...) async throws -> [String] {
    collectCalls += 1
    collectedMessages.append(messages)
    return messages
  }
}

class MockMaxArityLogService: MaxArityLogService, @unchecked Sendable {
  var counts = [Int]()

  func count(messages: String...) async throws -> Int {
    counts.append(messages.count)
    return messages.count
  }
}
