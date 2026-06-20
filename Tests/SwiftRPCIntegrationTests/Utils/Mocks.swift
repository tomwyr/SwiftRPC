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
      throw UserError.invalidCredentials
    }

    guard let result = loginResult else {
      throw UserError.profileNotFound
    }
    return result
  }

  func logout(token: AuthToken) async throws -> LogoutResponse {
    logoutCalls += 1
    guard let result = logoutResult else {
      throw UserError.updateFailed
    }
    return result
  }

  func register(email: String, password: String, profile: UserProfile) async throws -> UserID {
    registerCalls += 1
    guard let result = registerResult else {
      throw UserError.updateFailed
    }
    return result
  }

  func getProfile(userId: UserID) async throws -> UserProfile {
    getProfileCalls += 1
    getProfileUserIds.append(userId)

    guard let profile = profile else {
      throw UserError.profileNotFound
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
      throw UserError.updateFailed
    }
    return result
  }

  func batchDeleteUserIds(userIds: [UserID]) async throws -> Int {
    batchDeleteUserIdsCalls += 1
    guard let result = batchDeleteUserIdsResult else {
      throw UserError.updateFailed
    }
    return result
  }

  func upgradeAccount(userId: UserID, newType: AccountType) async throws -> Bool {
    upgradeAccountCalls += 1
    upgradeAccountUserIds.append(userId)
    upgradedAccountTypes.append(newType)
    guard let result = upgradeAccountResult else {
      throw UserError.updateFailed
    }
    return result
  }

  func getAccountType(userId: UserID) async throws -> AccountType {
    getAccountTypeCalls += 1
    getAccountTypeUserIds.append(userId)
    guard let result = getAccountTypeResult else {
      throw UserError.updateFailed
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
      throw UserError.updateFailed
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
      throw UserError.updateFailed
    }
    return result
  }
}

class MockUserErrorService: UserErrorService, @unchecked Sendable {
  enum FailureMode {
    case none
    case serviceError
    case rpcError
    case unknownError
  }

  var failureMode = FailureMode.none
  var typedFailureMode = FailureMode.none
  var authToken = AuthToken(token: "service-token", expiresAt: 3600)

  func authenticate(username: String, password: String) async throws -> AuthToken {
    switch failureMode {
    case .none:
      return authToken
    case .serviceError:
      throw UserError.invalidCredentials
    case .rpcError:
      throw RPCError(code: .unauthorized, message: "Unauthorized")
    case .unknownError:
      throw UnexpectedError()
    }
  }

  func authenticateWithFailure(username: String, password: String) async throws(
    RPCFailure<PasswordError>
  ) -> AuthToken {
    switch typedFailureMode {
    case .none:
      return authToken
    case .serviceError:
      throw .service(.expiredToken)
    case .rpcError:
      throw .rpc(RPCError(code: .unauthorized, message: "Unauthorized"))
    case .unknownError:
      throw .rpc(RPCError(code: .internalError, message: "Internal error"))
    }
  }

  func resetPassword(username: String) async throws(RPCFailure<PasswordError>) -> Bool {
    throw .service(.expiredToken)
  }
}

class MockPasswordFailureService: PasswordFailureService, @unchecked Sendable {
  var failureMode = MockUserErrorService.FailureMode.none
  var authToken = AuthToken(token: "password-service-token", expiresAt: 3600)

  func authenticateWithFailure(username: String, password: String) async throws(
    RPCFailure<PasswordError>
  ) -> AuthToken {
    switch failureMode {
    case .none:
      return authToken
    case .serviceError:
      throw .service(.expiredToken)
    case .rpcError:
      throw .rpc(RPCError(code: .unauthorized, message: "Unauthorized"))
    case .unknownError:
      throw .rpc(RPCError(code: .internalError, message: "Internal error"))
    }
  }
}

class MockInOutService: InOutService, @unchecked Sendable {
  var normalizedNames = [String]()
  var renamedUserIds = [UserID]()

  func normalize(name: inout String) async throws -> Bool {
    name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    normalizedNames.append(name)
    return !name.isEmpty
  }

  func swap(left: inout String, right: inout String) async throws {
    let originalLeft = left
    left = right
    right = originalLeft
  }

  func rename(userId: UserID, name: inout String) async throws -> String {
    renamedUserIds.append(userId)
    name = name.uppercased()
    return "\(userId):\(name)"
  }

  func fail(value: inout String) async throws {
    value = "server-mutated"
    throw RPCError(code: .badRequest, message: "Rejected")
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
