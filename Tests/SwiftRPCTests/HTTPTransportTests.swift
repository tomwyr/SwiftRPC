import Foundation
import Testing

@testable import SwiftRPC

@Suite struct HTTPTransportTests {
  @Test func successfulRequest() async throws {
    let session = MockTransportURLSession { request in
      let response = makeResponse(for: request, status: 200)
      let body = try rpcEncode(.success("test result"))
      return (body, response)
    }

    let transport = makeHTTPTransport(
      baseURL: "https://api.example.com", session: session,
    )

    let result = try await transport.send(
      route: "/test", input: "input", outputType: String.self,
    )

    #expect(result == "test result")
  }

  @Test func expectedEndpointUrl() async throws {
    var receivedURL: URL?

    let session = MockTransportURLSession { request in
      receivedURL = request.url
      let response = makeResponse(for: request, status: 200)
      let body = try rpcEncode(.success("result"))
      return (body, response)
    }

    let transport = makeHTTPTransport(
      baseURL: "https://api.example.com/api/v1", session: session,
    )

    _ = try await transport.send(
      route: "/test", input: "input", outputType: String.self,
    )

    let url = try #require(receivedURL?.absoluteString)
    #expect(url == "https://api.example.com/api/v1/test")
  }

  @Test func expectedHeaders() async throws {
    var receivedHeaders: [String: String]?

    let session = MockTransportURLSession { request in
      receivedHeaders = request.allHTTPHeaderFields
      let response = makeResponse(for: request, status: 200)
      let body = try rpcEncode(.success("result"))
      return (body, response)
    }

    let transport = makeHTTPTransport(
      baseURL: "https://api.example.com", session: session,
    )

    _ = try await transport.send(
      route: "/test", input: "input", outputType: String.self,
    )

    let headers = try #require(receivedHeaders)
    #expect(headers["Content-Type"] == "application/json")
    #expect(headers["Accept"] == "application/json")
  }

  @Test func unauthorized() async throws {
    let session = MockTransportURLSession { request in
      let response = makeResponse(for: request, status: 401)
      let body = Data()
      return (body, response)
    }

    let transport = makeHTTPTransport(
      baseURL: "https://api.example.com", session: session,
    )

    let caughtError = await #expect(throws: RPCError.self) {
      try await transport.send(
        route: "/test", input: "input", outputType: String.self,
      )
    }

    #expect(caughtError != nil)
    #expect(caughtError?.code == .unauthorized)
  }

  @Test func nonHTTPResponse() async throws {
    let session = MockTransportURLSession { request in
      let response = makeGenericResponse(for: request)
      let body = Data()
      return (body, response)
    }

    let transport = makeHTTPTransport(
      baseURL: "https://api.example.com", session: session,
    )

    let caughtError = await #expect(throws: RPCError.self) {
      try await transport.send(
        route: "/test", input: "input", outputType: String.self,
      )
    }

    #expect(caughtError != nil)
    #expect(caughtError?.code == .internalError)
  }

  @Test func payloadNestedTypes() async throws {
    let sentInput = [
      UserProfile(
        userId: UUID(),
        fullName: "Alice",
        accountSettings: AccountSettings(privateProfile: false, maxFollowers: 100, contentLanguage: "en"),
        accountTypes: [.standard]
      )
    ]
    let expectedOutput = [
      UserProfile(
        userId: UUID(),
        fullName: "Bob",
        accountSettings: AccountSettings(privateProfile: false, maxFollowers: 100, contentLanguage: "en"),
        accountTypes: [.premium]
      )
    ]

    var receivedInput: RPCRequest<[UserProfile]>?

    let session = MockTransportURLSession { request in
      receivedInput = try rpcDecode(request, into: [UserProfile].self)
      let response = makeResponse(for: request, status: 200)
      let body = try rpcEncode(.success(expectedOutput))
      return (body, response)
    }

    let transport = makeHTTPTransport(
      baseURL: "https://api.example.com", session: session,
    )

    let result = try await transport.send(
      route: "/test", input: sentInput, outputType: [UserProfile].self,
    )

    let rpcInput = try #require(receivedInput)
    #expect(rpcInput.input == sentInput)
    #expect(result == expectedOutput)
  }

  @Test func invalidRequest() async throws {
    let session = MockTransportURLSession { request in
      let error = RPCError(code: .badRequest, message: "Invalid input")
      let response = makeResponse(for: request, status: 200)
      let body = try rpcEncode(RPCResponse<String>.failure(error))
      return (body, response)
    }

    let transport = makeHTTPTransport(
      baseURL: "https://api.example.com", session: session,
    )

    let caughtError = await #expect(throws: RPCError.self) {
      try await transport.send(
        route: "/test", input: "input", outputType: String.self,
      )
    }

    #expect(caughtError != nil)
    #expect(caughtError?.code == .badRequest)
    #expect(caughtError?.message == "Invalid input")
  }

  @Test func uncaughtError() async throws {
    let session = MockTransportURLSession { request in
      throw NSError(domain: "TestError", code: -1, userInfo: nil)
    }

    let transport = makeHTTPTransport(
      baseURL: "https://api.example.com", session: session,
    )

    let caughtError = await #expect(throws: Error.self) {
      try await transport.send(
        route: "/test", input: "input", outputType: String.self,
      )
    }

    #expect(caughtError != nil)
  }
}
