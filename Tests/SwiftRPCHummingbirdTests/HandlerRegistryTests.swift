import Foundation
import Hummingbird
import Testing

@testable import SwiftRPC
@testable import SwiftRPCHummingbird

@Suite struct HummingbirdHandlerRegistryTests {
  var router = Router()
  var registry: HummingbirdHandlerRegistry<BasicRequestContext>

  init() {
    self.registry = HummingbirdHandlerRegistry(router: router)
  }

  @Test func simpleTypes() async throws {
    registry.register(method: "echo") { (input: String) in
      "Echo: \(input)"
    }

    let app = Application(router: router)

    try await app.test(.router) { client in
      let body = try rpcEncode("Hello, World!")

      try await client.executeRpc(uri: "/echo", body: body) { response in
        #expect(response.status == .ok)

        let responseBody = try rpcDecode(response.body, into: String.self)

        switch responseBody {
        case .success(let result):
          #expect(result == "Echo: Hello, World!")
        case .failure:
          Issue.record("Expected success but got failure")
        }
      }
    }
  }

  @Test func structTypes() async throws {
    registry.register(method: "process") { (input: UpdateProfileInput) in
      UpdateProfileResult(
        success: true,
        updatedAt: "2024-01-01"
      )
    }

    let app = Application(router: router)

    try await app.test(.router) { client in
      let testInput = UpdateProfileInput(userId: UUID(), email: "test@example.com", age: 30)
      let body = try rpcEncode(testInput)

      try await client.executeRpc(uri: "/process", body: body) { response in
        #expect(response.status == .ok)

        let responseBody = try rpcDecode(response.body, into: UpdateProfileResult.self)

        switch responseBody {
        case .success(let output):
          #expect(output.success == true)
        case .failure:
          Issue.record("Expected success but got failure")
        }
      }
    }
  }

  @Test func emptyInput() async throws {
    registry.register(method: "noInput") { (input: EmptyRequest) in
      "No input needed"
    }

    let app = Application(router: router)

    try await app.test(.router) { client in
      let body = try rpcEncode(EmptyRequest())

      try await client.executeRpc(uri: "/noInput", body: body) { response in
        #expect(response.status == .ok)

        let responseBody = try rpcDecode(response.body, into: String.self)

        switch responseBody {
        case .success(let result):
          #expect(result == "No input needed")
        case .failure:
          Issue.record("Expected success but got failure")
        }
      }
    }
  }

  @Test func emptyOutput() async throws {
    registry.register(method: "execute") { (input: String) in
      EmptyResponse()
    }

    let app = Application(router: router)

    try await app.test(.router) { client in
      let body = try rpcEncode("test")

      try await client.executeRpc(uri: "/execute", body: body) { response in
        #expect(response.status == .ok)

        let responseBody = try rpcDecode(response.body, into: EmptyResponse.self)

        switch responseBody {
        case .success:
          // Success
          break
        case .failure:
          Issue.record("Expected success but got failure")
        }
      }
    }
  }

  @Test func enumTypes() async throws {
    registry.register(method: "getEnum") { (input: String) in
      AccountType.premium
    }

    let app = Application(router: router)

    try await app.test(.router) { client in
      let body = try rpcEncode("test")

      try await client.executeRpc(uri: "/getEnum", body: body) { response in
        #expect(response.status == .ok)

        let responseBody = try rpcDecode(response.body, into: AccountType.self)

        switch responseBody {
        case .success(let enumValue):
          #expect(enumValue == .premium)
        case .failure:
          Issue.record("Expected success but got failure")
        }
      }
    }
  }

  @Test func nestedTypes() async throws {
    registry.register(method: "nested") { (input: UserProfile) in
      input
    }

    let app = Application(router: router)

    try await app.test(.router) { client in
      let input = UserProfile(
        userId: UUID(),
        fullName: "Test User",
        accountSettings: AccountSettings(
          privateProfile: true,
          maxFollowers: 1000,
          contentLanguage: "en",
        ),
        accountTypes: [.standard, .premium],
      )
      let body = try rpcEncode(input)

      try await client.executeRpc(uri: "/nested", body: body) { response in
        #expect(response.status == .ok)

        let responseBody = try rpcDecode(response.body, into: UserProfile.self)

        switch responseBody {
        case .success(let output):
          #expect(output == input)
        case .failure:
          Issue.record("Expected success but got failure")
        }
      }
    }
  }

  @Test func rpcErrorPropagation() async throws {
    let expectedError = RPCError(code: .notFound, message: "Resource not found")

    registry.register(method: "fail") { (input: String) -> String in
      throw expectedError
    }

    let app = Application(router: router)

    try await app.test(.router) { client in
      let body = try rpcEncode("test")

      try await client.executeRpc(uri: "/fail", body: body) { response in
        #expect(response.status == .ok)

        let responseBody = try rpcDecode(response.body, into: String.self)

        switch responseBody {
        case .success:
          Issue.record("Expected failure but got success")
        case .failure(.core(let error)):
          #expect(error.code == .notFound)
          #expect(error.message == "Resource not found")
        case .failure(.service):
          Issue.record("Expected core failure but got service failure")
        }
      }
    }
  }

  @Test func genericErrorConversion() async throws {
    registry.register(method: "genericFail") { (input: String) -> String in
      throw UserServiceError(message: "Generic error")
    }
    registry.register(method: "unexpectedFail") { (input: String) -> String in
      throw UnknownError()
    }

    let inputs = [
      ("/genericFail", "Generic error"),
      ("/unexpectedFail", "Internal error"),
    ]

    let app = Application(router: router)

    try await app.test(.router) { client in
      let body = try rpcEncode("test")

      for (uri, message) in inputs {
        try await client.executeRpc(uri: uri, body: body) { response in
          #expect(response.status == .ok)

          let responseBody = try rpcDecode(response.body, into: String.self)

          switch responseBody {
          case .success:
            Issue.record("Expected failure but got success")
          case .failure(.core(let error)):
            #expect(error.code == .internalError)
            #expect(error.message == message)
          case .failure(.service):
            Issue.record("Expected core failure but got service failure")
          }
        }
      }
    }
  }

  @Test func errorCodes() async throws {
    let errorCodes: [RPCErrorCode] = [
      .notFound, .badRequest, .unauthorized, .internalError,
    ]

    for errorCode in errorCodes {
      let router = Router()
      let registry = HummingbirdHandlerRegistry(router: router)

      registry.register(method: "testError") { (input: String) -> String in
        throw RPCError(code: errorCode, message: "Test error for \(errorCode)")
      }

      let app = Application(router: router)

      try await app.test(.router) { client in
        let body = try rpcEncode("test")

        try await client.executeRpc(uri: "/testError", body: body) { response in
          let responseBody = try rpcDecode(response.body, into: String.self)

          switch responseBody {
          case .success:
            Issue.record("Expected failure but got success for \(errorCode)")
          case .failure(.core(let error)):
            #expect(error.code == errorCode)
          case .failure(.service):
            Issue.record("Expected core failure but got service failure for \(errorCode)")
          }
        }
      }
    }
  }

  @Test func nonPostRequest() async throws {
    registry.register(method: "testMethod") { (input: String) in
      "Result"
    }

    let app = Application(router: router)

    try await app.test(.router) { client in
      let body = try rpcEncode("test")

      try await client.executeRpc(
        uri: "/testMethod", method: .get, body: body,
      ) { response in
        #expect(response.status == .notFound)
      }
    }
  }

  @Test func invalidBody() async throws {
    registry.register(method: "test") { (input: String) in
      "Result"
    }

    let app = Application(router: router)

    try await app.test(.router) { client in
      try await client.executeRpc(
        uri: "/test", method: .post, body: "{invalid json}",
      ) { response in
        #expect(response.status == .badRequest)
      }
    }
  }

  @Test func incompleteBody() async throws {
    registry.register(method: "test") { (input: UpdateProfileInput) in
      "Result"
    }

    let app = Application(router: router)

    try await app.test(.router) { client in
      // Send incomplete JSON missing required fields.
      let incompleteJSON = #"{"input": {"userId": "\#(UUID())"}}"#

      try await client.executeRpc(uri: "/test", body: incompleteJSON) { response in
        #expect(response.status == .badRequest)
      }
    }
  }

  @Test func emptyBody() async throws {
    registry.register(method: "test") { (input: String) in
      "Result"
    }

    let app = Application(router: router)

    try await app.test(.router) { client in
      try await client.executeRpc(uri: "/test", body: "") { response in
        #expect(response.status == .badRequest)
      }
    }
  }

  @Test func multipleMethods() async throws {
    registry.register(method: "method1") { (input: String) in
      "Method 1: \(input)"
    }

    registry.register(method: "method2") { (input: Int) in
      "Method 2: \(input * 2)"
    }

    registry.register(method: "method3") { (input: EmptyRequest) in
      true
    }

    let app = Application(router: router)

    try await app.test(.router) { client in
      // Test method1
      let body1 = try rpcEncode("test")
      try await client.executeRpc(uri: "/method1", body: body1) { response in
        #expect(response.status == .ok)

        let responseBody = try rpcDecode(response.body, into: String.self)

        switch responseBody {
        case .success(let result):
          #expect(result == "Method 1: test")
        case .failure:
          Issue.record("Expected success but got failure")
        }
      }

      // Test method2
      let body2 = try rpcEncode(21)
      try await client.executeRpc(uri: "/method2", body: body2) { response in
        #expect(response.status == .ok)

        let responseBody = try rpcDecode(response.body, into: String.self)

        switch responseBody {
        case .success(let result):
          #expect(result == "Method 2: 42")
        case .failure:
          Issue.record("Expected success but got failure")
        }
      }

      // Test method3
      let body3 = try rpcEncode(EmptyRequest())
      try await client.executeRpc(uri: "/method3", body: body3) { response in
        #expect(response.status == .ok)

        let responseBody = try rpcDecode(response.body, into: Bool.self)

        switch responseBody {
        case .success(let result):
          #expect(result == true)
        case .failure:
          Issue.record("Expected success but got failure")
        }
      }
    }
  }

  @Test func concurrentRequests() async throws {
    let counter = Counter()

    registry.register(method: "concurrent") { (input: Int) -> Int in
      await counter.increment()
      try await Task.sleep(for: .milliseconds(100))
      return input * 2
    }

    let app = Application(router: router)

    try await app.test(.router) { client in
      await withThrowingTaskGroup(of: Void.self) { group in
        for i in 1...10 {
          group.addTask {
            let body = try rpcEncode(i)
            try await client.executeRpc(uri: "/concurrent", body: body) { response in
              #expect(response.status == .ok)
            }
          }
        }
      }

      // Verify all requests were handled
      #expect(await counter.value == 10)
    }
  }
}
