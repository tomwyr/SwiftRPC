import Foundation
import Testing

@testable import SwiftRPC

@Suite struct InMemoryTransportTests {
  @Test func simpleParameterAndReturnType() async throws {
    let handler = TestServiceMock()
    let transport = InMemoryTransport()

    let server = TestServiceServer(handler: handler)
    server.register(on: transport)
    let client = TestServiceClient(transport: transport)

    let result = try await client.logIn(password: "test123")

    #expect(result == .success)
    #expect(handler.logInCalls == 1)
    #expect(handler.logInParams == ["test123"])
  }

  @Test func noParameters() async throws {
    let handler = TestServiceMock()
    let transport = InMemoryTransport()

    let server = TestServiceServer(handler: handler)
    server.register(on: transport)
    let client = TestServiceClient(transport: transport)

    let result = try await client.logOut()

    #expect(result == .success)
    #expect(handler.logOutCalls == 1)
  }

  @Test func structResult() async throws {
    let handler = TestServiceMock()
    handler.registerResults = [
      TestUser(id: UUID(), name: "Alice"),
      TestUser(id: UUID(), name: "Bob"),
    ]
    let transport = InMemoryTransport()

    let server = TestServiceServer(handler: handler)
    server.register(on: transport)
    let client = TestServiceClient(transport: transport)

    let user1 = try await client.register()
    let user2 = try await client.register()

    #expect(user1.name == "Alice")
    #expect(user2.name == "Bob")
    #expect(handler.registerCalls == 2)
  }

  @Test func structParameter() async throws {
    let handler = TestServiceMock()
    let transport = InMemoryTransport()

    let server = TestServiceServer(handler: handler)
    server.register(on: transport)
    let client = TestServiceClient(transport: transport)

    let user = TestUser(id: UUID(), name: "TestUser")
    let result = try await client.unregister(user: user)

    #expect(result == .success)
    #expect(handler.unregisterCalls == 1)
  }

  @Test func multipleSequentialCalls() async throws {
    let handler = TestServiceMock()
    let transport = InMemoryTransport()

    let server = TestServiceServer(handler: handler)
    server.register(on: transport)
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

  @Test func methodNotFound() async throws {
    let handler = TestServiceMock()
    let transport = InMemoryTransport()

    let server = TestServiceServer(handler: handler)
    server.register(on: transport)

    await #expect(throws: RPCError.self) {
      try await transport.send(route: "/nonExistent", input: "test", outputType: String.self)
    }
  }

  @Test func invalidInputType() async throws {
    let transport = InMemoryTransport()

    transport.register(method: "testMethod") { (input: String) -> String in
      return "test result"
    }

    await #expect(throws: RPCError.self) {
      try await transport.send(route: "/testMethod", input: 42, outputType: String.self)
    }
  }

  @Test func invalidOutputType() async throws {
    let transport = InMemoryTransport()

    transport.register(method: "testMethod") { (input: String) -> String in
      return "test result"
    }

    await #expect(throws: RPCError.self) {
      try await transport.send(route: "/testMethod", input: "test", outputType: Int.self)
    }
  }
}
