import Foundation
import Testing
import Vapor
import VaporTesting

@testable import SwiftRPC
@testable import SwiftRPCVapor

@RPC
protocol VaporEchoService {
  func echo(message: String) async throws -> String
}

struct VaporEchoHandler: VaporEchoService {
  func echo(message: String) async throws -> String {
    "Echo: \(message)"
  }
}

@Suite struct VaporHandlerRegistryTests {
  @Test func simpleTypes() async throws {
    try await withApp { app in
      let registry = VaporHandlerRegistry(routes: app.routes)
      registry.register(method: "echo") { (input: String) in
        "Echo: \(input)"
      }

      let body: ByteBuffer = try rpcEncode("Hello, World!")
      try await app.testing().test(.POST, "/echo", headers: rpcHeaders(), body: body) { response in
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
    try await withApp { app in
      let registry = VaporHandlerRegistry(routes: app.routes)
      registry.register(method: "process") { (input: UpdateProfileInput) in
        UpdateProfileResult(success: true, updatedAt: "2024-01-01")
      }

      let testInput = UpdateProfileInput(userId: UUID(), email: "test@example.com", age: 30)
      let body: ByteBuffer = try rpcEncode(testInput)

      try await app.testing().test(.POST, "/process", headers: rpcHeaders(), body: body) { response in
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
    try await withApp { app in
      let registry = VaporHandlerRegistry(routes: app.routes)
      registry.register(method: "noInput") { (input: EmptyRequest) in
        "No input needed"
      }

      let body: ByteBuffer = try rpcEncode(EmptyRequest())

      try await app.testing().test(.POST, "/noInput", headers: rpcHeaders(), body: body) { response in
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
    try await withApp { app in
      let registry = VaporHandlerRegistry(routes: app.routes)
      registry.register(method: "execute") { (input: String) in
        EmptyResponse()
      }

      let body: ByteBuffer = try rpcEncode("test")

      try await app.testing().test(.POST, "/execute", headers: rpcHeaders(), body: body) { response in
        #expect(response.status == .ok)

        let responseBody = try rpcDecode(response.body, into: EmptyResponse.self)

        switch responseBody {
        case .success:
          break
        case .failure:
          Issue.record("Expected success but got failure")
        }
      }
    }
  }

  @Test func rpcErrorPropagation() async throws {
    try await withApp { app in
      let registry = VaporHandlerRegistry(routes: app.routes)
      let expectedError = RPCError(code: .notFound, message: "Resource not found")

      registry.register(method: "fail") { (input: String) -> String in
        throw expectedError
      }

      let body: ByteBuffer = try rpcEncode("test")

      try await app.testing().test(.POST, "/fail", headers: rpcHeaders(), body: body) { response in
        #expect(response.status == .ok)

        let responseBody = try rpcDecode(response.body, into: String.self)

        switch responseBody {
        case .success:
          Issue.record("Expected failure but got success")
        case .failure(.rpc(let error)):
          #expect(error.code == .notFound)
          #expect(error.message == "Resource not found")
        case .failure(.service):
          Issue.record("Expected RPC failure but got service failure")
        }
      }
    }
  }

  @Test func serviceErrorPropagation() async throws {
    try await withApp { app in
      let registry = VaporHandlerRegistry(routes: app.routes)

      registry.register(method: "serviceFail") { (input: String) -> String in
        throw RPCServiceErrorEnvelope(TestServiceError(message: "Service failed"))
      }

      let body: ByteBuffer = try rpcEncode("test")

      try await app.testing().test(.POST, "/serviceFail", headers: rpcHeaders(), body: body) { response in
        #expect(response.status == .ok)

        let responseBody = try JSONDecoder().decode(
          RawServiceFailureResponse.self,
          from: Data(response.body.readableBytesView)
        )
        #expect(responseBody.error.type == "service")
        #expect(responseBody.error.payload.message == "Service failed")
      }
    }
  }

  @Test func genericErrorConversion() async throws {
    try await withApp { app in
      let registry = VaporHandlerRegistry(routes: app.routes)
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
      let body: ByteBuffer = try rpcEncode("test")

      for (uri, message) in inputs {
        try await app.testing().test(.POST, uri, headers: rpcHeaders(), body: body) { response in
          #expect(response.status == .ok)

          let responseBody = try rpcDecode(response.body, into: String.self)

          switch responseBody {
          case .success:
            Issue.record("Expected failure but got success")
          case .failure(.rpc(let error)):
            #expect(error.code == .internalError)
            #expect(error.message == message)
          case .failure(.service):
            Issue.record("Expected RPC failure but got service failure")
          }
        }
      }
    }
  }

  @Test func nonPostRequest() async throws {
    try await withApp { app in
      let registry = VaporHandlerRegistry(routes: app.routes)
      registry.register(method: "testMethod") { (input: String) in
        "Result"
      }

      let body: ByteBuffer = try rpcEncode("test")

      try await app.testing().test(.GET, "/testMethod", headers: rpcHeaders(), body: body) { response in
        #expect(response.status == .notFound)
      }
    }
  }

  @Test func invalidBody() async throws {
    try await withApp { app in
      let registry = VaporHandlerRegistry(routes: app.routes)
      registry.register(method: "test") { (input: String) in
        "Result"
      }

      try await app.testing().test(
        .POST,
        "/test",
        headers: rpcHeaders(),
        body: ByteBuffer(string: "{invalid json}")
      ) { response in
        #expect(response.status == .badRequest)
      }
    }
  }

  @Test func incompleteBody() async throws {
    try await withApp { app in
      let registry = VaporHandlerRegistry(routes: app.routes)
      registry.register(method: "test") { (input: UpdateProfileInput) in
        "Result"
      }

      let incompleteJSON = #"{"input": {"userId": "\#(UUID())"}}"#

      try await app.testing().test(
        .POST,
        "/test",
        headers: rpcHeaders(),
        body: ByteBuffer(string: incompleteJSON)
      ) { response in
        #expect(response.status == .badRequest)
      }
    }
  }

  @Test func emptyBody() async throws {
    try await withApp { app in
      let registry = VaporHandlerRegistry(routes: app.routes)
      registry.register(method: "test") { (input: String) in
        "Result"
      }

      try await app.testing().test(
        .POST,
        "/test",
        headers: rpcHeaders(),
        body: ByteBuffer()
      ) { response in
        #expect(response.status == .badRequest)
      }
    }
  }

  @Test func multipleMethods() async throws {
    try await withApp { app in
      let registry = VaporHandlerRegistry(routes: app.routes)
      registry.register(method: "method1") { (input: String) in
        "Method 1: \(input)"
      }
      registry.register(method: "method2") { (input: Int) in
        "Method 2: \(input * 2)"
      }
      registry.register(method: "method3") { (input: EmptyRequest) in
        true
      }

      let body1: ByteBuffer = try rpcEncode("test")
      try await app.testing().test(.POST, "/method1", headers: rpcHeaders(), body: body1) { response in
        let responseBody = try rpcDecode(response.body, into: String.self)
        if case .success(let result) = responseBody {
          #expect(result == "Method 1: test")
        } else {
          Issue.record("Expected success but got failure")
        }
      }

      let body2: ByteBuffer = try rpcEncode(21)
      try await app.testing().test(.POST, "/method2", headers: rpcHeaders(), body: body2) { response in
        let responseBody = try rpcDecode(response.body, into: String.self)
        if case .success(let result) = responseBody {
          #expect(result == "Method 2: 42")
        } else {
          Issue.record("Expected success but got failure")
        }
      }

      let body3: ByteBuffer = try rpcEncode(EmptyRequest())
      try await app.testing().test(.POST, "/method3", headers: rpcHeaders(), body: body3) { response in
        let responseBody = try rpcDecode(response.body, into: Bool.self)
        if case .success(let result) = responseBody {
          #expect(result == true)
        } else {
          Issue.record("Expected success but got failure")
        }
      }
    }
  }

  @Test func generatedServerRegistration() async throws {
    try await withApp { app in
      VaporEchoServiceServer(handler: VaporEchoHandler()).register(on: app.routes)

      let body = ByteBuffer(string: #"{"input":{"message":"test"}}"#)

      try await app.testing().test(.POST, "/echo", headers: rpcHeaders(), body: body) { response in
        #expect(response.status == .ok)

        let responseBody = try rpcDecode(response.body, into: String.self)
        if case .success(let result) = responseBody {
          #expect(result == "Echo: test")
        } else {
          Issue.record("Expected success but got failure")
        }
      }
    }
  }
}

private struct RawServiceFailureResponse: Decodable {
  let error: RawServiceFailure
}

private struct RawServiceFailure: Decodable {
  let type: String
  let payload: TestServiceError
}

private func rpcHeaders() -> HTTPHeaders {
  ["content-type": "application/json"]
}
