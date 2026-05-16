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

      private struct EchoRouterInputs {
        struct Ping: Codable {
          let message: String
        }
      }

      struct EchoRouterClient: Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func ping(message: String) async throws -> String {
          let input = EchoRouterInputs.Ping(message: message)
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

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "ping") { (input: EchoRouterInputs.Ping) in
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

      private struct PostRouterInputs {
        struct CreatePost: Codable {
          let title: String
          let body: String
          let authorId: UUID
        }
      }

      struct PostRouterClient: Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func createPost(title: String, body: String, authorId: UUID) async throws -> Post {
          let input = PostRouterInputs.CreatePost(title: title, body: body, authorId: authorId)
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

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "createPost") { (input: PostRouterInputs.CreatePost) in
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

      private struct HealthRouterInputs {
        struct Ping: Codable {
        }
      }

      struct HealthRouterClient: Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func ping() async throws -> String {
          let input = HealthRouterInputs.Ping()
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

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "ping") { (input: HealthRouterInputs.Ping) in
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

  @Test func noReturnTypeDefaultsToVoid() {
    assertMacro {
      """
      @RPC
      protocol CommandRouter {
        func execute(command: String) async throws
      }
      """
    } expansion: {
      """
      protocol CommandRouter {
        func execute(command: String) async throws
      }

      private struct CommandRouterInputs {
        struct Execute: Codable {
          let command: String
        }
      }

      struct CommandRouterClient: Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func execute(command: String) async throws -> Void {
          let input = CommandRouterInputs.Execute(command: command)
          return try await transport.send(
            route: "/execute",
            input: input,
            outputType: Void.self
          )
        }
      }

      struct CommandRouterServer<Handler: CommandRouter & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "execute") { (input: CommandRouterInputs.Execute) in
            try await self.handler.execute(command: input.command)
          }
        }
      }
      """
    }
  }
}