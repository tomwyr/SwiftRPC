import MacroTesting
import Testing

@testable import SwiftRPCMacros

@Suite(.macros(["RPC": RPCMacro.self]))
struct RPCMacroTests {
  @Test func singleMethodExpansion() {
    assertMacro {
      """
      @RPC
      protocol EchoRouter {
        func ping(message: String) async throws -> String
      }
      """
    } expansion: {
      """
      protocol EchoRouter {
        func ping(message: String) async throws -> String
      }

      struct EchoRouterClient: Sendable {
          private let transport: any RPCTransport

          init(transport: any RPCTransport) {
              self.transport = transport
          }

          init(baseURL: URL) {
              self.transport = HTTPTransport(baseURL: baseURL)
          }

          private struct _PingInput: Codable {
              let message: String
          }

          func ping(message: String) async throws -> String {
              let input = _PingInput(message: message)
              return try await transport.send(
                  route: "/ping",
                  input: input,
                  outputType: String.self
              )
          }
      }

      struct EchoRouterServer<Handler: EchoRouter & Sendable>: RPCServer {
          private let handler: Handler

          init(handler: Handler) {
              self.handler = handler
          }

          private struct _PingInput: Codable {
              let message: String
          }

          func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "ping") { (input: _PingInput) in
              try await self.handler.ping(message: input.message)
          }
          }
      }
      """
    }
  }

  @Test func multipleParametersWrappedIntoInputStruct() {
    assertMacro {
      """
      @RPC
      protocol PostRouter {
        func createPost(title: String, body: String, authorId: UUID) async throws -> Post
      }
      """
    } expansion: {
      """
      protocol PostRouter {
        func createPost(title: String, body: String, authorId: UUID) async throws -> Post
      }

      struct PostRouterClient: Sendable {
          private let transport: any RPCTransport

          init(transport: any RPCTransport) {
              self.transport = transport
          }

          init(baseURL: URL) {
              self.transport = HTTPTransport(baseURL: baseURL)
          }

          private struct _CreatePostInput: Codable {
              let title: String
              let body: String
              let authorId: UUID
          }

          func createPost(title: String, body: String, authorId: UUID) async throws -> Post {
              let input = _CreatePostInput(title: title, body: body, authorId: authorId)
              return try await transport.send(
                  route: "/createPost",
                  input: input,
                  outputType: Post.self
              )
          }
      }

      struct PostRouterServer<Handler: PostRouter & Sendable>: RPCServer {
          private let handler: Handler

          init(handler: Handler) {
              self.handler = handler
          }

          private struct _CreatePostInput: Codable {
              let title: String
              let body: String
              let authorId: UUID
          }

          func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "createPost") { (input: _CreatePostInput) in
              try await self.handler.createPost(title: input.title, body: input.body, authorId: input.authorId)
          }
          }
      }
      """
    }
  }

  @Test func noParameterMethod() {
    assertMacro {
      """
      @RPC
      protocol HealthRouter {
        func ping() async throws -> String
      }
      """
    } expansion: {
      """
      protocol HealthRouter {
        func ping() async throws -> String
      }

      struct HealthRouterClient: Sendable {
          private let transport: any RPCTransport

          init(transport: any RPCTransport) {
              self.transport = transport
          }

          init(baseURL: URL) {
              self.transport = HTTPTransport(baseURL: baseURL)
          }

          private struct _PingInput: Codable {
          }

          func ping() async throws -> String {
              let input = _PingInput()
              return try await transport.send(
                  route: "/ping",
                  input: input,
                  outputType: String.self
              )
          }
      }

      struct HealthRouterServer<Handler: HealthRouter & Sendable>: RPCServer {
          private let handler: Handler

          init(handler: Handler) {
              self.handler = handler
          }

          private struct _PingInput: Codable {
          }

          func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "ping") { (input: _PingInput) in
              try await self.handler.ping()
          }
          }
      }
      """
    }
  }

  @Test func diagnosticOnNonProtocol() {
    assertMacro {
      """
      @RPC
      struct NotAProtocol {}
      """
    } diagnostics: {
      """
      @RPC
      ┬───
      ╰─ 🛑 @RPC can only be applied to a protocol
      struct NotAProtocol {}
      """
    } expansion: {
      """

      """
    }
  }

  @Test func diagnosticOnNonAsyncThrowsMethod() {
    assertMacro {
      """
      @RPC
      protocol BadRouter {
        func sync(id: String) -> String
      }
      """
    } diagnostics: {
      """
      @RPC
      ┬───
      ╰─ 🛑 @RPC: 'sync' must be declared 'async throws'
      protocol BadRouter {
        func sync(id: String) -> String
      }
      """
    } expansion: {
      """
      """
    }
  }
}