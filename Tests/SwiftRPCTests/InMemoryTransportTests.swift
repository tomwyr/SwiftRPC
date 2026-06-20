import Foundation
import Testing

@testable import SwiftRPC

@Suite struct InMemoryTransportTests {
  @Test func simpleType() async throws {
    nonisolated(unsafe) var receivedInput: String?

    let registry = InMemoryHandlerRegistry()
    registry.register(method: "greet") { (input: String) -> String in
      receivedInput = input
      return "world"
    }
    let transport = InMemoryTransport(from: registry)

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
      accountSettings: AccountSettings(
        privateProfile: false, maxFollowers: 100, contentLanguage: "en"),
      accountTypes: [.standard]
    )
    let output = UserProfile(
      userId: UUID(),
      fullName: "Bob",
      accountSettings: AccountSettings(
        privateProfile: false, maxFollowers: 100, contentLanguage: "en"),
      accountTypes: [.premium]
    )

    let registry = InMemoryHandlerRegistry()
    registry.register(method: "process") { (input: UserProfile) in
      receivedInput = input
      return output
    }
    let transport = InMemoryTransport(from: registry)

    let result = try await transport.send(
      route: "/process", input: input, outputType: UserProfile.self,
    )

    #expect(receivedInput == input)
    #expect(result == output)
  }

  @Test func unregisteredMethod() async throws {
    let transport = InMemoryTransport(from: InMemoryHandlerRegistry())

    await #expect(throws: RPCError.self) {
      try await transport.send(
        route: "/nonexistent", input: "", outputType: String.self,
      )
    }
  }

  @Test func routeWithoutLeadingSlash() async throws {
    let registry = InMemoryHandlerRegistry()
    registry.register(method: "test") { (_: String) -> String in
      "success"
    }
    let transport = InMemoryTransport(from: registry)

    await #expect(throws: RPCError.self) {
      try await transport.send(
        route: "test", input: "", outputType: String.self,
      )
    }
  }

  @Test func invalidInputType() async throws {
    let registry = InMemoryHandlerRegistry()
    registry.register(method: "process") { (input: String) -> String in
      "success"
    }
    let transport = InMemoryTransport(from: registry)

    await #expect(throws: RPCError.self) {
      try await transport.send(
        route: "/process", input: 123, outputType: String.self,
      )
    }
  }

  @Test func invalidOutputType() async throws {
    let registry = InMemoryHandlerRegistry()
    registry.register(method: "process") { (_: String) -> Int in
      42
    }
    let transport = InMemoryTransport(from: registry)

    await #expect(throws: RPCError.self) {
      try await transport.send(
        route: "/process", input: "input", outputType: String.self,
      )
    }
  }

  @Test func serviceError() async throws {
    let serviceError = UserError.rejected(reason: "No")
    let registry = InMemoryHandlerRegistry()
    registry.register(method: "process") { (_: String) -> String in
      throw RPCServiceErrorEnvelope(serviceError)
    }
    let transport = InMemoryTransport(from: registry)

    let caughtError = await #expect(throws: UserError.self) {
      try await transport.send(
        route: "/process",
        input: "input",
        outputType: String.self,
        serviceErrorType: UserError.self,
      )
    }

    #expect(caughtError == serviceError)
  }

  @Test func concurrentSends() async throws {
    let registry = InMemoryHandlerRegistry()
    registry.register(method: "double") { (input: Int) -> Int in
      input * 2
    }
    let transport = InMemoryTransport(from: registry)

    let results = try await withThrowingTaskGroup(of: Int.self) { group in
      for input in 0..<100 {
        group.addTask {
          try await transport.send(
            route: "/double",
            input: input,
            outputType: Int.self,
          )
        }
      }

      var results: [Int] = []
      for try await result in group {
        results.append(result)
      }
      return results
    }

    #expect(results.sorted() == Array(stride(from: 0, to: 200, by: 2)))
  }
}
