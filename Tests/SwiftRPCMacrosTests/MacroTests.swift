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

  @Test func customCodableTypes() {
    assertMacro {
      """
      struct CustomItem: Codable {
        let id: UUID
        let name: String
        let tags: [String]
      }

      struct ResultType: Codable {
        let success: Bool
        let data: String
      }

      @RPC
      protocol ComplexRouter {
        func processItems(items: [CustomItem]) async throws -> [ResultType]
      }
      """
    } expansion: {
      """
      struct CustomItem: Codable {
        let id: UUID
        let name: String
        let tags: [String]
      }

      struct ResultType: Codable {
        let success: Bool
        let data: String
      }
      protocol ComplexRouter {
        func processItems(items: [CustomItem]) async throws -> [ResultType]
      }

      private struct Inputs {
        struct ProcessItems: Codable {
          let items: [CustomItem]
        }
      }

      private struct Outputs {
        struct Nothing: Codable {
        }
      }

      struct ComplexRouterClient: Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func processItems(items: [CustomItem]) async throws -> [ResultType] {
          let input = Inputs.ProcessItems(items: items)
          return try await transport.send(
            route: "/processItems",
            input: input,
            outputType: [ResultType].self,
          )
        }
      }

      struct ComplexRouterServer<Handler: ComplexRouter & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "processItems") { (input: Inputs.ProcessItems) in
            try await self.handler.processItems(items: input.items)
          }
        }
      }
      """
    }
  }

  @Test func builtInCodableTypes() {
    assertMacro {
      """
      @RPC
      protocol BuiltInRouter {
        func processDate(date: Date) async throws -> Date
        func processURL(url: URL) async throws -> URL
        func processUUID(uuid: UUID) async throws -> UUID
        func processData(data: Data) async throws -> Data
      }
      """
    } expansion: {
      """
      protocol BuiltInRouter {
        func processDate(date: Date) async throws -> Date
        func processURL(url: URL) async throws -> URL
        func processUUID(uuid: UUID) async throws -> UUID
        func processData(data: Data) async throws -> Data
      }

      private struct Inputs {
        struct ProcessDate: Codable {
          let date: Date
        }

        struct ProcessURL: Codable {
          let url: URL
        }

        struct ProcessUUID: Codable {
          let uuid: UUID
        }

        struct ProcessData: Codable {
          let data: Data
        }
      }

      private struct Outputs {
        struct Nothing: Codable {
        }
      }

      struct BuiltInRouterClient: Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func processDate(date: Date) async throws -> Date {
          let input = Inputs.ProcessDate(date: date)
          return try await transport.send(
            route: "/processDate",
            input: input,
            outputType: Date.self,
          )
        }

        func processURL(url: URL) async throws -> URL {
          let input = Inputs.ProcessURL(url: url)
          return try await transport.send(
            route: "/processURL",
            input: input,
            outputType: URL.self,
          )
        }

        func processUUID(uuid: UUID) async throws -> UUID {
          let input = Inputs.ProcessUUID(uuid: uuid)
          return try await transport.send(
            route: "/processUUID",
            input: input,
            outputType: UUID.self,
          )
        }

        func processData(data: Data) async throws -> Data {
          let input = Inputs.ProcessData(data: data)
          return try await transport.send(
            route: "/processData",
            input: input,
            outputType: Data.self,
          )
        }
      }

      struct BuiltInRouterServer<Handler: BuiltInRouter & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "processDate") { (input: Inputs.ProcessDate) in
            try await self.handler.processDate(date: input.date)
          }

          registry.register(method: "processURL") { (input: Inputs.ProcessURL) in
            try await self.handler.processURL(url: input.url)
          }

          registry.register(method: "processUUID") { (input: Inputs.ProcessUUID) in
            try await self.handler.processUUID(uuid: input.uuid)
          }

          registry.register(method: "processData") { (input: Inputs.ProcessData) in
            try await self.handler.processData(data: input.data)
          }
        }
      }
      """
    }
  }

  @Test func multipleProtocolsInSameFile() {
    assertMacro {
      """
      @RPC
      protocol FirstRouter {
        func firstMethod() async throws -> String
      }

      @RPC
      protocol SecondRouter {
        func secondMethod() async throws -> Int
      }
      """
    } expansion: {
      """
      protocol FirstRouter {
        func firstMethod() async throws -> String
      }

      private struct Inputs {
        struct FirstMethod: Codable {
        }
      }

      private struct Outputs {
        struct Nothing: Codable {
        }
      }

      struct FirstRouterClient: Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func firstMethod() async throws -> String {
          let input = Inputs.FirstMethod()
          return try await transport.send(
            route: "/firstMethod",
            input: input,
            outputType: String.self,
          )
        }
      }

      struct FirstRouterServer<Handler: FirstRouter & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "firstMethod") { (input: Inputs.FirstMethod) in
            try await self.handler.firstMethod()
          }
        }
      }
      protocol SecondRouter {
        func secondMethod() async throws -> Int
      }

      private struct Inputs {
        struct SecondMethod: Codable {
        }
      }

      private struct Outputs {
        struct Nothing: Codable {
        }
      }

      struct SecondRouterClient: Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func secondMethod() async throws -> Int {
          let input = Inputs.SecondMethod()
          return try await transport.send(
            route: "/secondMethod",
            input: input,
            outputType: Int.self,
          )
        }
      }

      struct SecondRouterServer<Handler: SecondRouter & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "secondMethod") { (input: Inputs.SecondMethod) in
            try await self.handler.secondMethod()
          }
        }
      }
      """
    }
  }

  @Test func emptyProtocol() {
    assertMacro {
      """
      @RPC
      protocol EmptyRouter {
      }
      """
    } expansion: {
      """
      protocol EmptyRouter {
      }

      private struct Inputs {

      }

      private struct Outputs {
        struct Nothing: Codable {
        }
      }

      struct EmptyRouterClient: Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }


      }

      struct EmptyRouterServer<Handler: EmptyRouter & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {

        }
      }
      """
    }
  }
}

struct RPCMacroDiagnosticsTests {
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
    }
  }

  @Test func diagnosticOnThrowsOnlyMethod() {
    assertMacro {
      """
      @RPC
      protocol BadRouter {
        func throwsOnly(id: String) throws -> String
      }
      """
    } diagnostics: {
      """
      @RPC
      ┬───
      ╰─ 🛑 @RPC: 'throwsOnly' must be declared 'async throws'
      protocol BadRouter {
        func throwsOnly(id: String) throws -> String
      }
      """
    }
  }

  @Test func diagnosticOnAsyncOnlyMethod() {
    assertMacro {
      """
      @RPC
      protocol BadRouter {
        func asyncOnly(id: String) async -> String
      }
      """
    } diagnostics: {
      """
      @RPC
      ┬───
      ╰─ 🛑 @RPC: 'asyncOnly' must be declared 'async throws'
      protocol BadRouter {
        func asyncOnly(id: String) async -> String
      }
      """
    }
  }

  @Test func diagnosticOnMethodWithNeitherAsyncNorThrows() {
    assertMacro {
      """
      @RPC
      protocol BadRouter {
        func regular(id: String) -> String
      }
      """
    } diagnostics: {
      """
      @RPC
      ┬───
      ╰─ 🛑 @RPC: 'regular' must be declared 'async throws'
      protocol BadRouter {
        func regular(id: String) -> String
      }
      """
    }
  }
}
