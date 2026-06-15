import Foundation
import Testing

@testable import SwiftRPC

@Suite(.serialized) struct IntegrationTests {
  let handler: MockUserService
  let server: UserServiceServer<MockUserService>

  init() {
    self.handler = MockUserService()
    self.server = UserServiceServer(handler: handler)
  }
}

// Input-output types tests
extension IntegrationTests {
  @Test(arguments: runners)
  func noInputWithPrimitiveOutput(runner: IntegrationTestRunner) async throws {
    handler.validateSessionResult = true

    try await runner.run(server) { transport in
      let client = UserServiceClient(transport: transport)

      let result = try await client.validateSession()

      #expect(result == true)
      #expect(handler.validateSessionCalls == 1)
    }
  }

  @Test(arguments: runners)
  func primitiveInputWithStructOutput(runner: IntegrationTestRunner) async throws {
    let expectedProfile = UserProfile(
      userId: "user-001",
      email: "alice@example.com",
      fullName: "Alice Johnson",
      settings: UserSettings(notificationsEnabled: true, theme: "dark", sessionTimeout: 30),
      accountType: .standard,
    )
    handler.profile = expectedProfile

    try await runner.run(server) { transport in
      let client = UserServiceClient(transport: transport)

      let profile = try await client.getProfile(userId: "user-001")

      #expect(profile == expectedProfile)
      #expect(handler.getProfileCalls == 1)
      #expect(handler.getProfileUserIds == ["user-001"])
    }
  }

  @Test(arguments: runners)
  func mixedInputWithPrimitiveOutput(runner: IntegrationTestRunner) async throws {
    let profile = UserProfile(
      userId: "",
      email: "alice@example.com",
      fullName: "Alice Johnson",
      settings: UserSettings(notificationsEnabled: true, theme: "dark", sessionTimeout: 30),
      accountType: .standard,
    )
    handler.registerResult = "user-001"

    try await runner.run(server) { transport in
      let client = UserServiceClient(transport: transport)

      let userId = try await client.register(
        email: "alice@example.com",
        password: "securePass",
        profile: profile,
      )

      #expect(userId == "user-001")
      #expect(handler.registerCalls == 1)
    }
  }

  @Test(arguments: runners)
  func primitiveInputWithArrayOutput(runner: IntegrationTestRunner) async throws {
    let searchResults = [
      UserProfile(
        userId: "user-001",
        email: "alice@example.com",
        fullName: "Alice Johnson",
        settings: UserSettings(notificationsEnabled: true, theme: "dark", sessionTimeout: 30),
        accountType: .standard,
      ),
      UserProfile(
        userId: "user-002",
        email: "alice.smith@example.com",
        fullName: "Alice Smith",
        settings: UserSettings(notificationsEnabled: false, theme: "light", sessionTimeout: 30),
        accountType: .premium,
      ),
    ]
    handler.searchResults = searchResults

    try await runner.run(server) { transport in
      let client = UserServiceClient(transport: transport)

      let results = try await client.searchUsers(query: "Alice", limit: 10)

      #expect(results.count == 2)
      #expect(results[0].fullName == "Alice Johnson")
      #expect(results[1].fullName == "Alice Smith")
      #expect(handler.searchUsersCalls == 1)
    }
  }

  @Test(arguments: runners)
  func arrayInputWithPrimitiveOutput(runner: IntegrationTestRunner) async throws {
    handler.batchDeleteUserIdsResult = 3

    try await runner.run(server) { transport in
      let client = UserServiceClient(transport: transport)

      let deletedCount = try await client.batchDeleteUserIds(userIds: [
        "user-001", "user-002", "user-003",
      ])

      #expect(deletedCount == 3)
      #expect(handler.batchDeleteUserIdsCalls == 1)
    }
  }

  @Test(arguments: runners)
  func enumInputWithPrimitiveOutput(runner: IntegrationTestRunner) async throws {
    handler.upgradeAccountResult = true

    try await runner.run(server) { transport in
      let client = UserServiceClient(transport: transport)

      let result = try await client.upgradeAccount(userId: "user-001", newType: .premium)

      #expect(result == true)
      #expect(handler.upgradeAccountCalls == 1)
      #expect(handler.upgradeAccountUserIds == ["user-001"])
      #expect(handler.upgradedAccountTypes == [.premium])
    }
  }

  @Test(arguments: runners)
  func primitiveInputWithEnumOutput(runner: IntegrationTestRunner) async throws {
    handler.getAccountTypeResult = .standard

    try await runner.run(server) { transport in
      let client = UserServiceClient(transport: transport)

      let accountType = try await client.getAccountType(userId: "user-001")

      #expect(accountType == .standard)
      #expect(handler.getAccountTypeCalls == 1)
      #expect(handler.getAccountTypeUserIds == ["user-001"])
    }
  }

  @Test(arguments: runners)
  func voidInputWithVoidOutput(runner: IntegrationTestRunner) async throws {
    try await runner.run(server) { transport in
      let client = UserServiceClient(transport: transport)

      try await client.clearCache()

      #expect(handler.clearCacheCalls == 1)
    }
  }

  @Test(arguments: runners)
  func optionalInputs(runner: IntegrationTestRunner) async throws {
    let expectedSettings = UserSettings(
      notificationsEnabled: true,
      theme: "dark",
      sessionTimeout: 30,
    )
    handler.updateSettingsResult = expectedSettings

    try await runner.run(server) { transport in
      let client = UserServiceClient(transport: transport)

      let result = try await client.updateSettings(
        userId: "user-001",
        notificationsEnabled: true,
        theme: nil,
        sessionTimeout: nil,
      )

      #expect(result == expectedSettings)
      #expect(handler.updateSettingsCalls == 1)
      #expect(handler.updateSettingsUserIds == ["user-001"])
      #expect(handler.updateSettingsNotificationsEnabled == [true])
      #expect(handler.updateSettingsThemes == [nil])
      #expect(handler.updateSettingsSessionTimeouts == [nil])
    }
  }

  @Test(arguments: runners)
  func optionalResult(runner: IntegrationTestRunner) async throws {
    handler.settings = nil

    try await runner.run(server) { transport in
      let client = UserServiceClient(transport: transport)

      do {
        let result = try await client.getSettings(userId: "user-999")
        #expect(result == nil)
        #expect(handler.getSettingsCalls == 1)
        #expect(handler.getSettingsUserIds == ["user-999"])
      } catch DecodingError.keyNotFound {
        #expect(runner is HummingbirdTestRunner)
        #expect(handler.getSettingsCalls == 1)
        #expect(handler.getSettingsUserIds == ["user-999"])
      }
    }
  }

  @Test(arguments: runners)
  func optionalResultWithValue(runner: IntegrationTestRunner) async throws {
    let expectedSettings = UserSettings(
      notificationsEnabled: true,
      theme: "dark",
      sessionTimeout: 30,
    )
    handler.settings = expectedSettings

    try await runner.run(server) { transport in
      let client = UserServiceClient(transport: transport)

      let result = try await client.getSettings(userId: "user-001")

      #expect(result == expectedSettings)
      #expect(handler.getSettingsCalls == 1)
      #expect(handler.getSettingsUserIds == ["user-001"])
    }
  }
}

// Behavior tests
extension IntegrationTests {
  @Test(arguments: runners)
  func sequentialCallsToMultipleMethods(runner: IntegrationTestRunner) async throws {
    handler.loginResult = AuthToken(token: "abc123xyz", expiresAt: 1_704_067_200)
    handler.profile = UserProfile(
      userId: "user-001",
      email: "alice@example.com",
      fullName: "Alice Johnson",
      settings: UserSettings(notificationsEnabled: true, theme: "dark", sessionTimeout: 30),
      accountType: .standard,
    )
    handler.validateSessionResult = true
    handler.upgradeAccountResult = true
    handler.getAccountTypeResult = .premium

    try await runner.run(server) { transport in
      let client = UserServiceClient(transport: transport)

      _ = try await client.login(username: "alice", password: "pass1")
      _ = try await client.login(username: "bob", password: "pass2")
      _ = try await client.login(username: "charlie", password: "pass3")

      _ = try await client.getProfile(userId: "user-001")
      _ = try await client.getProfile(userId: "user-002")

      _ = try await client.validateSession()
      _ = try await client.validateSession()
      _ = try await client.validateSession()
      _ = try await client.validateSession()

      _ = try await client.upgradeAccount(userId: "user-001", newType: .premium)
      _ = try await client.upgradeAccount(userId: "user-002", newType: .standard)

      _ = try await client.getAccountType(userId: "user-001")
      _ = try await client.getAccountType(userId: "user-002")

      #expect(handler.loginCalls == 3)
      #expect(handler.loginUsernames == ["alice", "bob", "charlie"])

      #expect(handler.getProfileCalls == 2)
      #expect(handler.getProfileUserIds == ["user-001", "user-002"])

      #expect(handler.validateSessionCalls == 4)

      #expect(handler.upgradeAccountCalls == 2)
      #expect(handler.upgradeAccountUserIds == ["user-001", "user-002"])
      #expect(handler.upgradedAccountTypes == [.premium, .standard])

      #expect(handler.getAccountTypeCalls == 2)
      #expect(handler.getAccountTypeUserIds == ["user-001", "user-002"])
    }
  }

  @Test(arguments: runners)
  func parallelCallsToMultipleMethods(runner: IntegrationTestRunner) async throws {
    handler.loginResult = AuthToken(token: "abc123xyz", expiresAt: 1_704_067_200)
    handler.profile = UserProfile(
      userId: "user-001",
      email: "alice@example.com",
      fullName: "Alice Johnson",
      settings: UserSettings(notificationsEnabled: true, theme: "dark", sessionTimeout: 30),
      accountType: .standard,
    )
    handler.validateSessionResult = true
    handler.upgradeAccountResult = true
    handler.getAccountTypeResult = .premium

    try await runner.run(server) { transport in
      let client = UserServiceClient(transport: transport)

      async let loginTasks = [
        client.login(username: "alice", password: "pass1"),
        client.login(username: "bob", password: "pass2"),
        client.login(username: "charlie", password: "pass3"),
      ]

      async let profileTasks = [
        client.getProfile(userId: "user-001"),
        client.getProfile(userId: "user-002"),
      ]

      async let validationTasks = [
        client.validateSession(),
        client.validateSession(),
        client.validateSession(),
        client.validateSession(),
      ]

      async let upgradeTasks = [
        client.upgradeAccount(userId: "user-001", newType: .premium),
        client.upgradeAccount(userId: "user-002", newType: .standard),
      ]

      async let accountTypeTasks = [
        client.getAccountType(userId: "user-001"),
        client.getAccountType(userId: "user-002"),
      ]

      _ = try await loginTasks
      _ = try await profileTasks
      _ = try await validationTasks
      _ = try await upgradeTasks
      _ = try await accountTypeTasks

      #expect(handler.loginCalls == 3)
      #expect(handler.loginUsernames.sorted() == ["alice", "bob", "charlie"])

      #expect(handler.getProfileCalls == 2)
      #expect(handler.getProfileUserIds.sorted() == ["user-001", "user-002"])

      #expect(handler.validateSessionCalls == 4)

      #expect(handler.upgradeAccountCalls == 2)
      #expect(handler.upgradeAccountUserIds.sorted() == ["user-001", "user-002"])

      #expect(handler.getAccountTypeCalls == 2)
      #expect(handler.getAccountTypeUserIds.sorted() == ["user-001", "user-002"])
    }
  }
}

// Error tests
extension IntegrationTests {
  @Test(arguments: runners)
  func errorPropagation(runner: IntegrationTestRunner) async throws {
    handler.shouldFailLogin = true

    try await runner.run(server) { transport in
      let client = UserServiceClient(transport: transport)

      let error = await #expect(throws: RPCError.self) {
        try await client.login(username: "alice", password: "wrong")
      }

      #expect(error?.message == "Internal error")
    }
  }

  @Test(arguments: runners)
  func customErrorMessages(runner: IntegrationTestRunner) async throws {
    handler.customLoginError = RPCError(
      code: .unauthorized,
      message: "Invalid credentials provided"
    )

    try await runner.run(server) { transport in
      let client = UserServiceClient(transport: transport)

      let error = await #expect(throws: RPCError.self) {
        try await client.login(username: "alice", password: "wrong")
      }

      #expect(error?.code == .unauthorized)
      #expect(error?.message == "Invalid credentials provided")
    }
  }
}

// Inline handler tests
extension IntegrationTests {
  @Test(arguments: runners)
  func inlineServerHandlerRoutesClientCalls(runner: IntegrationTestRunner) async throws {
    nonisolated(unsafe) var capturedQuery = ""

    let server = MovieServiceServer(
      handler: .inline(
        search: { @Sendable query in
          capturedQuery = query
          return Movie(title: "batman", duration: 120)
        },
      )
    )

    try await runner.run(server) { transport in
      let client = MovieServiceClient(transport: transport)

      let result = try await client.search(query: "bat")

      #expect(result.title == "batman")
      #expect(result.duration == 120)
      #expect(capturedQuery == "bat")
    }
  }
}

// Variadic parameter tests
extension IntegrationTests {
  @Test(arguments: runners)
  func variadicParametersRouteZeroOneAndMultipleValues(
    runner: IntegrationTestRunner,
  ) async throws {
    let handler = MockLogService()
    let server = LogServiceServer(handler: handler)

    try await runner.run(server) { transport in
      let client = LogServiceClient(transport: transport)

      let empty = try await client.collect(prefix: "empty")
      let single = try await client.collect(prefix: "single", messages: "one")
      let multiple = try await client.collect(prefix: "multiple", messages: "one", "two", "three")

      #expect(empty == ["empty"])
      #expect(single == ["single", "one"])
      #expect(multiple == ["multiple", "one", "two", "three"])
      #expect(handler.collectCalls == 3)
      #expect(handler.collectedPrefixes == ["empty", "single", "multiple"])
      #expect(handler.collectedMessages == [[], ["one"], ["one", "two", "three"]])
    }
  }

  @Test(arguments: runners)
  func variadicParametersRejectValuesAboveMaxArity(
    runner: IntegrationTestRunner,
  ) async throws {
    let handler = MockLogService()
    let server = LogServiceServer(handler: handler)

    try await runner.run(server) { transport in
      let client = LogServiceClient(transport: transport)

      let error = await #expect(throws: RPCError.self) {
        try await client.collect(prefix: "overflow", messages: "one", "two", "three", "four")
      }

      #expect(error?.code == .badRequest)
      #expect(handler.collectCalls == 0)
    }
  }

  @Test(arguments: runners)
  func variadicParametersCanTruncateValuesAboveMaxArity(
    runner: IntegrationTestRunner,
  ) async throws {
    let handler = MockTruncatingLogService()
    let server = TruncatingLogServiceServer(handler: handler)

    try await runner.run(server) { transport in
      let client = TruncatingLogServiceClient(transport: transport)

      let result = try await client.collect(messages: "one", "two", "three", "four")

      #expect(result == ["one", "two"])
      #expect(handler.collectCalls == 1)
      #expect(handler.collectedMessages == [["one", "two"]])
    }
  }

  @Test(arguments: runners)
  func variadicParametersSupportAbsoluteMaximumArity(
    runner: IntegrationTestRunner,
  ) async throws {
    let handler = MockMaxArityLogService()
    let server = MaxArityLogServiceServer(handler: handler)

    try await runner.run(server) { transport in
      let client = MaxArityLogServiceClient(transport: transport)

      let result = try await client.count(
        messages:
          "1", "2", "3", "4", "5", "6", "7", "8",
        "9", "10", "11", "12", "13", "14", "15", "16",
        "17", "18", "19", "20", "21", "22", "23", "24",
        "25", "26", "27", "28", "29", "30", "31", "32",
      )

      #expect(result == 32)
      #expect(handler.counts == [32])
    }
  }

  @Test(arguments: runners)
  func variadicParametersWithInlineHandler(runner: IntegrationTestRunner) async throws {
    nonisolated(unsafe) var capturedMessages = [String]()

    let server = InlineLogServiceServer(
      handler: .inline(
        collect: { @Sendable (messages: String...) async throws -> [String] in
          capturedMessages = messages
          return messages
        },
      )
    )

    try await runner.run(server) { transport in
      let client = InlineLogServiceClient(transport: transport)

      let result = try await client.collect(messages: "one", "two")

      #expect(result == ["one", "two"])
      #expect(capturedMessages == ["one", "two"])
    }
  }
}

// Type conformance tests
extension IntegrationTests {
  @Test(arguments: runners)
  func generatedClientConformsToServiceProtocol(runner: IntegrationTestRunner) async throws {
    let handler = MockEchoService()
    handler.pingResult = "pong"

    let server = EchoServiceServer(handler: handler)

    try await runner.run(server) { transport in
      let service: any EchoService = EchoServiceClient(transport: transport)

      let result = try await service.ping()

      #expect(result == "pong")
      #expect(handler.pingCalls == 1)
    }
  }
}
