import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import SwiftRPCMacros

let macros = ["RPC": RPCMacro.self]

@Test func singleMethodExpansion() {
  assertMacroExpansion(
    """
    @RPC
    protocol EchoRouter {
      func ping(message: String) async throws -> String
    }
    """,
    expandedSource: """
      protocol EchoRouter {
        func ping(message: String) async throws -> String
      }

      public struct EchoRouterClient: Sendable {
        private let transport: any RPCTransport

        public init(transport: any RPCTransport) {
          self.transport = transport
        }

        public init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        private struct _PingInput: Codable {
          let message: String
        }

        public func ping(message: String) async throws -> String {
            let input = _PingInput(message: message)
            return try await transport.send(
            route: "/ping",
            input: input,
            outputType: String.self
            )
          }
        }

        public struct EchoRouterServer<Handler: EchoRouter>: Sendable {
          private let handler: Handler

          public init(handler: Handler) {
            self.handler = handler
          }

          private struct _PingInput: Codable {
            let message: String
          }

          public func register(on registry: any RPCHandlerRegistry) {
            registry.register(method: "ping") { input in
                try await self.handler.ping(message: input.message)
            }
          }
        }
      }
      """,
    macros: macros,
  )
}

@Test func multipleParametersWrappedIntoInputStruct() {
  assertMacroExpansion(
    """
    @RPC
    protocol PostRouter {
      func createPost(title: String, body: String, authorId: UUID) async throws -> Post
    }
    """,
    expandedSource: """
      protocol PostRouter {
        func createPost(title: String, body: String, authorId: UUID) async throws -> Post
      }

      public struct PostRouterClient: Sendable {
        private let transport: any RPCTransport

        public init(transport: any RPCTransport) {
          self.transport = transport
        }

        public init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        private struct _CreatePostInput: Codable {
          let title: String
          let body: String
          let authorId: UUID
        }

        public func createPost(title: String, body: String, authorId: UUID) async throws -> Post {
          let input = _CreatePostInput(title: title, body: body, authorId: authorId)
          return try await transport.send(
            route: "/createPost",
            input: input,
            outputType: Post.self
          )
        }
      }

      public struct PostRouterServer<Handler: PostRouter>: Sendable {
        private let handler: Handler

        public init(handler: Handler) {
          self.handler = handler
        }

        private struct _CreatePostInput: Codable {
          let title: String
          let body: String
          let authorId: UUID
        }

        public func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "createPost") { input in
            try await self.handler.createPost(title: input.title, body: input.body, authorId: input.authorId)
          }
        }
      }
      """,
    macros: macros,
  )
}

@Test func noParameterMethod() {
  assertMacroExpansion(
    """
    @RPC
    protocol HealthRouter {
      func ping() async throws -> String
    }
    """,
    expandedSource: """
      protocol HealthRouter {
        func ping() async throws -> String
      }

      public struct HealthRouterClient: Sendable {
        private let transport: any RPCTransport

        public init(transport: any RPCTransport) {
          self.transport = transport
        }

        public init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        private struct _PingInput: Codable {}

        public func ping() async throws -> String {
            let input = _PingInput()
            return try await transport.send(
                route: "/ping",
                input: input,
                outputType: String.self
            )
        }
      }

      public struct HealthRouterServer<Handler: HealthRouter>: Sendable {
        private let handler: Handler

        public init(handler: Handler) {
            self.handler = handler
        }

        private struct _PingInput: Codable {}

        public func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "ping") { input in
            try await self.handler.ping()
          }
        }
      }
      """,
    macros: macros,
  )
}

@Test func diagnosticOnNonProtocol() {
  assertMacroExpansion(
    """
    @RPC
    struct NotAProtocol {}
    """,
    expandedSource: """
      struct NotAProtocol {}
      """,
    diagnostics: [
      DiagnosticSpec(
        message: "@RPC can only be applied to a protocol",
        line: 1, column: 1,
      )
    ],
    macros: macros,
  )
}

@Test func diagnosticOnNonAsyncThrowsMethod() {
  assertMacroExpansion(
    """
    @RPC
    protocol BadRouter {
      func sync(id: String) -> String
    }
    """,
    expandedSource: """
      protocol BadRouter {
        func sync(id: String) -> String
      }
      """,
    diagnostics: [
      DiagnosticSpec(
        message: "@RPC: 'sync' must be declared 'async throws'",
        line: 1, column: 1,
      )
    ],
    macros: macros,
  )
}
