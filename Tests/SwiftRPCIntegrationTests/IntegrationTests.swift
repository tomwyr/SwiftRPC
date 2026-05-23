import Foundation
import Testing

@Suite(.serialized) struct IntegrationTests {
  static let runners: [IntegrationTestRunner] = [
    InMemoryTestRunner(),
    HummingbirdTestRunner(),
  ]

  let handler: MockUserService
  let server: UserServiceServer<MockUserService>

  init() {
    self.handler = MockUserService()
    self.server = UserServiceServer(handler: handler)
  }

  @Test(arguments: runners)
  func simpleParameterAndReturnType(runner: IntegrationTestRunner) async throws {
    try await runner.run(handler, server) { transport in
      let client = UserServiceClient(transport: transport)

      let result = try await client.logIn(password: "test123")

      #expect(result == .success)
      #expect(handler.logInCalls == 1)
      #expect(handler.logInParams == ["test123"])
    }
  }

  @Test(arguments: runners)
  func noParameters(runner: IntegrationTestRunner) async throws {
    try await runner.run(handler, server) { transport in
      let client = UserServiceClient(transport: transport)

      let result = try await client.logOut()

      #expect(result == 1)
      #expect(handler.logOutCalls == 1)
    }
  }

  @Test(arguments: runners)
  func structResult(runner: IntegrationTestRunner) async throws {
    handler.createResults = [
      UserProfile(
        userId: UUID(),
        fullName: "Alice",
        accountSettings: AccountSettings(privateProfile: false, maxFollowers: 100, contentLanguage: "en"),
        accountTypes: [.standard]
      ),
      UserProfile(
        userId: UUID(),
        fullName: "Bob",
        accountSettings: AccountSettings(privateProfile: true, maxFollowers: 50, contentLanguage: "en"),
        accountTypes: [.premium]
      ),
    ]

    try await runner.run(handler, server) { transport in
      let client = UserServiceClient(transport: transport)

      let user1 = try await client.create()
      let user2 = try await client.create()

      #expect(user1.fullName == "Alice")
      #expect(user2.fullName == "Bob")
      #expect(handler.createCalls == 2)
    }
  }

  @Test(arguments: runners)
  func structParameter(runner: IntegrationTestRunner) async throws {
    try await runner.run(handler, server) { transport in
      let client = UserServiceClient(transport: transport)

      let user = UserProfile(
        userId: UUID(),
        fullName: "TestUser",
        accountSettings: AccountSettings(privateProfile: false, maxFollowers: 100, contentLanguage: "en"),
        accountTypes: [.standard]
      )
      let result = try await client.delete(user: user)

      #expect(result == true)
      #expect(handler.deleteCalls == 1)
    }
  }

  @Test(arguments: runners)
  func multipleSequentialCalls(runner: IntegrationTestRunner) async throws {
    try await runner.run(handler, server) { transport in
      let client = UserServiceClient(transport: transport)

      let result1 = try await client.logIn(password: "password1")
      let result2 = try await client.logIn(password: "password2")
      let result3 = try await client.logOut()

      #expect(result1 == .success)
      #expect(result2 == .success)
      #expect(result3 == 1)
      #expect(handler.logInCalls == 2)
      #expect(handler.logInParams == ["password1", "password2"])
      #expect(handler.logOutCalls == 1)
    }
  }
}
