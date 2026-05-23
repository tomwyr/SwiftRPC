import Foundation
import Testing

@testable import SwiftRPC

@Suite struct InMemoryTransportTests {
  @Test func simpleType() async throws {
    nonisolated(unsafe) var receivedInput: String?

    let transport = InMemoryTransport()
    transport.register(method: "greet") { (input: String) -> String in
      receivedInput = input
      return "world"
    }

    let result = try await transport.send(
      route: "/greet", input: "hello", outputType: String.self,
    )

    #expect(receivedInput == "hello")
    #expect(result == "world")
  }

  @Test func customType() async throws {
    nonisolated(unsafe) var receivedInput: UserProfile?

    let input = UserProfile(
      userId: UUID(),
      fullName: "Alice",
      accountSettings: AccountSettings(privateProfile: false, maxFollowers: 100, contentLanguage: "en"),
      accountTypes: [.standard]
    )
    let output = UserProfile(
      userId: UUID(),
      fullName: "Bob",
      accountSettings: AccountSettings(privateProfile: false, maxFollowers: 100, contentLanguage: "en"),
      accountTypes: [.premium]
    )

    let transport = InMemoryTransport()
    transport.register(method: "process") { (input: UserProfile) in
      receivedInput = input
      return output
    }

    let result = try await transport.send(
      route: "/process", input: input, outputType: UserProfile.self,
    )

    #expect(receivedInput == input)
    #expect(result == output)
  }

  @Test func unregisteredMethod() async throws {
    let transport = InMemoryTransport()

    await #expect(throws: RPCError.self) {
      try await transport.send(
        route: "/nonexistent", input: "", outputType: String.self,
      )
    }
  }

  @Test func routeWithoutLeadingSlash() async throws {
    let transport = InMemoryTransport()
    transport.register(method: "test") { (_: String) -> String in
      "success"
    }

    await #expect(throws: RPCError.self) {
      try await transport.send(
        route: "test", input: "", outputType: String.self,
      )
    }
  }

  @Test func invalidInputType() async throws {
    let transport = InMemoryTransport()
    transport.register(method: "process") { (input: String) -> String in
      "success"
    }

    await #expect(throws: RPCError.self) {
      try await transport.send(
        route: "/process", input: 123, outputType: String.self,
      )
    }
  }

  @Test func invalidOutputType() async throws {
    let transport = InMemoryTransport()
    transport.register(method: "process") { (_: String) -> Int in
      42
    }

    await #expect(throws: RPCError.self) {
      try await transport.send(
        route: "/process", input: "input", outputType: String.self,
      )
    }
  }
}
