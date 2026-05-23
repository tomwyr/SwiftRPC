import Foundation
import Testing

@Suite(.serialized) struct IntegrationTests {
  static let runners: [IntegrationTestRunner] = [
    InMemoryTestRunner(),
    HummingbirdTestRunner(),
  ]

  let handler: MockTestService
  let server: TestServiceServer<MockTestService>

  init() {
    self.handler = MockTestService()
    self.server = TestServiceServer(handler: handler)
  }

  @Test(arguments: runners)
  func simpleParameterAndReturnType(runner: IntegrationTestRunner) async throws {
    try await runner.run(handler, server) { transport in
      let client = TestServiceClient(transport: transport)

      let result = try await client.logIn(password: "test123")

      #expect(result == .success)
      #expect(handler.logInCalls == 1)
      #expect(handler.logInParams == ["test123"])
    }
  }

  @Test(arguments: runners)
  func noParameters(runner: IntegrationTestRunner) async throws {
    try await runner.run(handler, server) { transport in
      let client = TestServiceClient(transport: transport)

      let result = try await client.logOut()

      #expect(result == .success)
      #expect(handler.logOutCalls == 1)
    }
  }

  @Test(arguments: runners)
  func structResult(runner: IntegrationTestRunner) async throws {
    handler.registerResults = [
      TestUser(id: UUID(), name: "Alice"),
      TestUser(id: UUID(), name: "Bob"),
    ]

    try await runner.run(handler, server) { transport in
      let client = TestServiceClient(transport: transport)

      let user1 = try await client.register()
      let user2 = try await client.register()

      #expect(user1.name == "Alice")
      #expect(user2.name == "Bob")
      #expect(handler.registerCalls == 2)
    }
  }

  @Test(arguments: runners)
  func structParameter(runner: IntegrationTestRunner) async throws {
    try await runner.run(handler, server) { transport in
      let client = TestServiceClient(transport: transport)

      let user = TestUser(id: UUID(), name: "TestUser")
      let result = try await client.unregister(user: user)

      #expect(result == .success)
      #expect(handler.unregisterCalls == 1)
    }
  }

  @Test(arguments: runners)
  func multipleSequentialCalls(runner: IntegrationTestRunner) async throws {
    try await runner.run(handler, server) { transport in
      let client = TestServiceClient(transport: transport)

      let result1 = try await client.logIn(password: "password1")
      let result2 = try await client.logIn(password: "password2")
      let result3 = try await client.logOut()

      #expect(result1 == .success)
      #expect(result2 == .success)
      #expect(result3 == .success)
      #expect(handler.logInCalls == 2)
      #expect(handler.logInParams == ["password1", "password2"])
      #expect(handler.logOutCalls == 1)
    }
  }
}
