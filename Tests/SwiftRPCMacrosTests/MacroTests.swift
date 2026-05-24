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

      private struct Inputs {
        struct Ping: Codable {
          let message: String
        }
      }

      private struct Outputs {
        struct Nothing: Codable {
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
          let input = Inputs.Ping(message: message)
          return try await transport.send(
            route: "/ping",
            input: input,
            outputType: String.self,
          )
        }
      }

      struct EchoRouterServer<Handler: EchoRouter & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "ping") { (input: Inputs.Ping) in
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

      private struct Inputs {
        struct CreatePost: Codable {
          let title: String
          let body: String
          let authorId: UUID
        }
      }

      private struct Outputs {
        struct Nothing: Codable {
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
          let input = Inputs.CreatePost(title: title, body: body, authorId: authorId)
          return try await transport.send(
            route: "/createPost",
            input: input,
            outputType: Post.self,
          )
        }
      }

      struct PostRouterServer<Handler: PostRouter & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "createPost") { (input: Inputs.CreatePost) in
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

      private struct Inputs {
        struct Ping: Codable {
        }
      }

      private struct Outputs {
        struct Nothing: Codable {
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
          let input = Inputs.Ping()
          return try await transport.send(
            route: "/ping",
            input: input,
            outputType: String.self,
          )
        }
      }

      struct HealthRouterServer<Handler: HealthRouter & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "ping") { (input: Inputs.Ping) in
            try await self.handler.ping()
          }
        }
      }
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

      private struct Inputs {
        struct Execute: Codable {
          let command: String
        }
      }

      private struct Outputs {
        struct Nothing: Codable {
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

        func execute(command: String) async throws {
          let input = Inputs.Execute(command: command)
          _ = try await transport.send(
            route: "/execute",
            input: input,
            outputType: Outputs.Nothing.self,
          )
        }
      }

      struct CommandRouterServer<Handler: CommandRouter & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "execute") { (input: Inputs.Execute) in
            try await self.handler.execute(command: input.command)
            return Outputs.Nothing()
          }
        }
      }
      """
    }
  }

  @Test func mixedVoidAndNonVoidMethods() {
    assertMacro {
      """
      @RPC
      protocol HybridRouter {
        func getData(id: String) async throws -> Data
        func setData(id: String, value: Data) async throws
        func getStatus() async throws -> String
        func clearCache() async throws -> Void
      }
      """
    } expansion: {
      """
      protocol HybridRouter {
        func getData(id: String) async throws -> Data
        func setData(id: String, value: Data) async throws
        func getStatus() async throws -> String
        func clearCache() async throws -> Void
      }

      private struct Inputs {
        struct GetData: Codable {
          let id: String
        }

        struct SetData: Codable {
          let id: String
          let value: Data
        }

        struct GetStatus: Codable {
        }

        struct ClearCache: Codable {
        }
      }

      private struct Outputs {
        struct Nothing: Codable {
        }
      }

      struct HybridRouterClient: Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func getData(id: String) async throws -> Data {
          let input = Inputs.GetData(id: id)
          return try await transport.send(
            route: "/getData",
            input: input,
            outputType: Data.self,
          )
        }

        func setData(id: String, value: Data) async throws {
          let input = Inputs.SetData(id: id, value: value)
          _ = try await transport.send(
            route: "/setData",
            input: input,
            outputType: Outputs.Nothing.self,
          )
        }

        func getStatus() async throws -> String {
          let input = Inputs.GetStatus()
          return try await transport.send(
            route: "/getStatus",
            input: input,
            outputType: String.self,
          )
        }

        func clearCache() async throws {
          let input = Inputs.ClearCache()
          _ = try await transport.send(
            route: "/clearCache",
            input: input,
            outputType: Outputs.Nothing.self,
          )
        }
      }

      struct HybridRouterServer<Handler: HybridRouter & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "getData") { (input: Inputs.GetData) in
            try await self.handler.getData(id: input.id)
          }

          registry.register(method: "setData") { (input: Inputs.SetData) in
            try await self.handler.setData(id: input.id, value: input.value)
            return Outputs.Nothing()
          }

          registry.register(method: "getStatus") { (input: Inputs.GetStatus) in
            try await self.handler.getStatus()
          }

          registry.register(method: "clearCache") { (input: Inputs.ClearCache) in
            try await self.handler.clearCache()
            return Outputs.Nothing()
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
