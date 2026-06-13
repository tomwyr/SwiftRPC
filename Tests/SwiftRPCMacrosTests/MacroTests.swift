import MacroTesting
import Testing

@testable import SwiftRPCMacros

@Suite(.macros(["RPC": RPCMacro.self]))
struct RPCMacroTests {
  @Test func singleMethodExpansion() {
    assertMacro {
      """
      @RPC
      protocol EchoService {
        func ping(message: String) async throws -> String
      }
      """
    } expansion: {
      """
      protocol EchoService {
        func ping(message: String) async throws -> String
      }

      private struct EchoServiceInputs {
        struct Ping: Codable {
          let message: String
        }
      }

      private struct EchoServiceOutputs {
        struct Nothing: Codable {
        }
      }

      struct EchoServiceClient: EchoService, Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func ping(message: String) async throws -> String {
          let input = EchoServiceInputs.Ping(message: message)
          return try await transport.send(
            route: "/ping",
            input: input,
            outputType: String.self,
          )
        }
      }

      struct EchoServiceServer<Handler: EchoService & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "ping") { (input: EchoServiceInputs.Ping) in
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
      protocol PostService {
        func createPost(title: String, body: String, authorId: UUID) async throws -> Post
      }
      """
    } expansion: {
      """
      protocol PostService {
        func createPost(title: String, body: String, authorId: UUID) async throws -> Post
      }

      private struct PostServiceInputs {
        struct CreatePost: Codable {
          let title: String
          let body: String
          let authorId: UUID
        }
      }

      private struct PostServiceOutputs {
        struct Nothing: Codable {
        }
      }

      struct PostServiceClient: PostService, Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func createPost(title: String, body: String, authorId: UUID) async throws -> Post {
          let input = PostServiceInputs.CreatePost(title: title, body: body, authorId: authorId)
          return try await transport.send(
            route: "/createPost",
            input: input,
            outputType: Post.self,
          )
        }
      }

      struct PostServiceServer<Handler: PostService & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "createPost") { (input: PostServiceInputs.CreatePost) in
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
      protocol HealthService {
        func ping() async throws -> String
      }
      """
    } expansion: {
      """
      protocol HealthService {
        func ping() async throws -> String
      }

      private struct HealthServiceInputs {
        struct Ping: Codable {
        }
      }

      private struct HealthServiceOutputs {
        struct Nothing: Codable {
        }
      }

      struct HealthServiceClient: HealthService, Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func ping() async throws -> String {
          let input = HealthServiceInputs.Ping()
          return try await transport.send(
            route: "/ping",
            input: input,
            outputType: String.self,
          )
        }
      }

      struct HealthServiceServer<Handler: HealthService & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "ping") { (input: HealthServiceInputs.Ping) in
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
      protocol CommandService {
        func execute(command: String) async throws
      }
      """
    } expansion: {
      """
      protocol CommandService {
        func execute(command: String) async throws
      }

      private struct CommandServiceInputs {
        struct Execute: Codable {
          let command: String
        }
      }

      private struct CommandServiceOutputs {
        struct Nothing: Codable {
        }
      }

      struct CommandServiceClient: CommandService, Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func execute(command: String) async throws {
          let input = CommandServiceInputs.Execute(command: command)
          _ = try await transport.send(
            route: "/execute",
            input: input,
            outputType: CommandServiceOutputs.Nothing.self,
          )
        }
      }

      struct CommandServiceServer<Handler: CommandService & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "execute") { (input: CommandServiceInputs.Execute) in
            try await self.handler.execute(command: input.command)
            return CommandServiceOutputs.Nothing()
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
      protocol HybridService {
        func getData(id: String) async throws -> Data
        func setData(id: String, value: Data) async throws
        func getStatus() async throws -> String
        func clearCache() async throws -> Void
      }
      """
    } expansion: {
      """
      protocol HybridService {
        func getData(id: String) async throws -> Data
        func setData(id: String, value: Data) async throws
        func getStatus() async throws -> String
        func clearCache() async throws -> Void
      }

      private struct HybridServiceInputs {
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

      private struct HybridServiceOutputs {
        struct Nothing: Codable {
        }
      }

      struct HybridServiceClient: HybridService, Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func getData(id: String) async throws -> Data {
          let input = HybridServiceInputs.GetData(id: id)
          return try await transport.send(
            route: "/getData",
            input: input,
            outputType: Data.self,
          )
        }

        func setData(id: String, value: Data) async throws {
          let input = HybridServiceInputs.SetData(id: id, value: value)
          _ = try await transport.send(
            route: "/setData",
            input: input,
            outputType: HybridServiceOutputs.Nothing.self,
          )
        }

        func getStatus() async throws -> String {
          let input = HybridServiceInputs.GetStatus()
          return try await transport.send(
            route: "/getStatus",
            input: input,
            outputType: String.self,
          )
        }

        func clearCache() async throws {
          let input = HybridServiceInputs.ClearCache()
          _ = try await transport.send(
            route: "/clearCache",
            input: input,
            outputType: HybridServiceOutputs.Nothing.self,
          )
        }
      }

      struct HybridServiceServer<Handler: HybridService & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "getData") { (input: HybridServiceInputs.GetData) in
            try await self.handler.getData(id: input.id)
          }

          registry.register(method: "setData") { (input: HybridServiceInputs.SetData) in
            try await self.handler.setData(id: input.id, value: input.value)
            return HybridServiceOutputs.Nothing()
          }

          registry.register(method: "getStatus") { (input: HybridServiceInputs.GetStatus) in
            try await self.handler.getStatus()
          }

          registry.register(method: "clearCache") { (input: HybridServiceInputs.ClearCache) in
            try await self.handler.clearCache()
            return HybridServiceOutputs.Nothing()
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
      protocol ComplexService {
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
      protocol ComplexService {
        func processItems(items: [CustomItem]) async throws -> [ResultType]
      }

      private struct ComplexServiceInputs {
        struct ProcessItems: Codable {
          let items: [CustomItem]
        }
      }

      private struct ComplexServiceOutputs {
        struct Nothing: Codable {
        }
      }

      struct ComplexServiceClient: ComplexService, Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func processItems(items: [CustomItem]) async throws -> [ResultType] {
          let input = ComplexServiceInputs.ProcessItems(items: items)
          return try await transport.send(
            route: "/processItems",
            input: input,
            outputType: [ResultType].self,
          )
        }
      }

      struct ComplexServiceServer<Handler: ComplexService & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "processItems") { (input: ComplexServiceInputs.ProcessItems) in
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
      protocol BuiltInService {
        func processDate(date: Date) async throws -> Date
        func processURL(url: URL) async throws -> URL
        func processUUID(uuid: UUID) async throws -> UUID
        func processData(data: Data) async throws -> Data
      }
      """
    } expansion: {
      """
      protocol BuiltInService {
        func processDate(date: Date) async throws -> Date
        func processURL(url: URL) async throws -> URL
        func processUUID(uuid: UUID) async throws -> UUID
        func processData(data: Data) async throws -> Data
      }

      private struct BuiltInServiceInputs {
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

      private struct BuiltInServiceOutputs {
        struct Nothing: Codable {
        }
      }

      struct BuiltInServiceClient: BuiltInService, Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func processDate(date: Date) async throws -> Date {
          let input = BuiltInServiceInputs.ProcessDate(date: date)
          return try await transport.send(
            route: "/processDate",
            input: input,
            outputType: Date.self,
          )
        }

        func processURL(url: URL) async throws -> URL {
          let input = BuiltInServiceInputs.ProcessURL(url: url)
          return try await transport.send(
            route: "/processURL",
            input: input,
            outputType: URL.self,
          )
        }

        func processUUID(uuid: UUID) async throws -> UUID {
          let input = BuiltInServiceInputs.ProcessUUID(uuid: uuid)
          return try await transport.send(
            route: "/processUUID",
            input: input,
            outputType: UUID.self,
          )
        }

        func processData(data: Data) async throws -> Data {
          let input = BuiltInServiceInputs.ProcessData(data: data)
          return try await transport.send(
            route: "/processData",
            input: input,
            outputType: Data.self,
          )
        }
      }

      struct BuiltInServiceServer<Handler: BuiltInService & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "processDate") { (input: BuiltInServiceInputs.ProcessDate) in
            try await self.handler.processDate(date: input.date)
          }

          registry.register(method: "processURL") { (input: BuiltInServiceInputs.ProcessURL) in
            try await self.handler.processURL(url: input.url)
          }

          registry.register(method: "processUUID") { (input: BuiltInServiceInputs.ProcessUUID) in
            try await self.handler.processUUID(uuid: input.uuid)
          }

          registry.register(method: "processData") { (input: BuiltInServiceInputs.ProcessData) in
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
      protocol FirstService {
        func firstMethod() async throws -> String
      }

      @RPC
      protocol SecondService {
        func secondMethod() async throws -> Int
      }
      """
    } expansion: {
      """
      protocol FirstService {
        func firstMethod() async throws -> String
      }

      private struct FirstServiceInputs {
        struct FirstMethod: Codable {
        }
      }

      private struct FirstServiceOutputs {
        struct Nothing: Codable {
        }
      }

      struct FirstServiceClient: FirstService, Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func firstMethod() async throws -> String {
          let input = FirstServiceInputs.FirstMethod()
          return try await transport.send(
            route: "/firstMethod",
            input: input,
            outputType: String.self,
          )
        }
      }

      struct FirstServiceServer<Handler: FirstService & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "firstMethod") { (input: FirstServiceInputs.FirstMethod) in
            try await self.handler.firstMethod()
          }
        }
      }
      protocol SecondService {
        func secondMethod() async throws -> Int
      }

      private struct SecondServiceInputs {
        struct SecondMethod: Codable {
        }
      }

      private struct SecondServiceOutputs {
        struct Nothing: Codable {
        }
      }

      struct SecondServiceClient: SecondService, Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func secondMethod() async throws -> Int {
          let input = SecondServiceInputs.SecondMethod()
          return try await transport.send(
            route: "/secondMethod",
            input: input,
            outputType: Int.self,
          )
        }
      }

      struct SecondServiceServer<Handler: SecondService & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "secondMethod") { (input: SecondServiceInputs.SecondMethod) in
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
      protocol EmptyService {
      }
      """
    } expansion: {
      """
      protocol EmptyService {
      }

      private struct EmptyServiceInputs {

      }

      private struct EmptyServiceOutputs {
        struct Nothing: Codable {
        }
      }

      struct EmptyServiceClient: EmptyService, Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }


      }

      struct EmptyServiceServer<Handler: EmptyService & Sendable>: RPCServer {
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

  @Test func protocolInheritance() {
    assertMacro {
      """
      protocol BaseAuthProtocol {
        func refreshToken(token: String) async throws -> String
        func revokeToken(token: String) async throws
      }

      @RPC
      protocol UserAuthProtocol: BaseAuthProtocol {
        func authenticateUser(email: String, password: String) async throws -> AuthToken
        func logoutUser(userId: UUID) async throws
      }
      """
    } expansion: {
      """
      protocol BaseAuthProtocol {
        func refreshToken(token: String) async throws -> String
        func revokeToken(token: String) async throws
      }
      protocol UserAuthProtocol: BaseAuthProtocol {
        func authenticateUser(email: String, password: String) async throws -> AuthToken
        func logoutUser(userId: UUID) async throws
      }

      private struct UserAuthProtocolInputs {
        struct AuthenticateUser: Codable {
          let email: String
          let password: String
        }

        struct LogoutUser: Codable {
          let userId: UUID
        }
      }

      private struct UserAuthProtocolOutputs {
        struct Nothing: Codable {
        }
      }

      struct UserAuthProtocolClient: UserAuthProtocol, Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func authenticateUser(email: String, password: String) async throws -> AuthToken {
          let input = UserAuthProtocolInputs.AuthenticateUser(email: email, password: password)
          return try await transport.send(
            route: "/authenticateUser",
            input: input,
            outputType: AuthToken.self,
          )
        }

        func logoutUser(userId: UUID) async throws {
          let input = UserAuthProtocolInputs.LogoutUser(userId: userId)
          _ = try await transport.send(
            route: "/logoutUser",
            input: input,
            outputType: UserAuthProtocolOutputs.Nothing.self,
          )
        }
      }

      struct UserAuthProtocolServer<Handler: UserAuthProtocol & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "authenticateUser") { (input: UserAuthProtocolInputs.AuthenticateUser) in
            try await self.handler.authenticateUser(email: input.email, password: input.password)
          }

          registry.register(method: "logoutUser") { (input: UserAuthProtocolInputs.LogoutUser) in
            try await self.handler.logoutUser(userId: input.userId)
            return UserAuthProtocolOutputs.Nothing()
          }
        }
      }
      """
    }
  }

  @Test func privateAccessModifiers() {
    assertMacro {
      """
      @RPC
      private protocol PrivateService {
        private func processData(id: String) async throws -> String
      }
      """
    } expansion: {
      """
      private protocol PrivateService {
        private func processData(id: String) async throws -> String
      }

      private struct PrivateServiceInputs {
        struct ProcessData: Codable {
          let id: String
        }
      }

      private struct PrivateServiceOutputs {
        struct Nothing: Codable {
        }
      }

      private struct PrivateServiceClient: PrivateService, Sendable {
        private let transport: any RPCTransport

        private init(transport: any RPCTransport) {
          self.transport = transport
        }

        private init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        private func processData(id: String) async throws -> String {
          let input = PrivateServiceInputs.ProcessData(id: id)
          return try await transport.send(
            route: "/processData",
            input: input,
            outputType: String.self,
          )
        }
      }

      private struct PrivateServiceServer<Handler: PrivateService & Sendable>: RPCServer {
        private let handler: Handler

        private init(handler: Handler) {
          self.handler = handler
        }

        private func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "processData") { (input: PrivateServiceInputs.ProcessData) in
            try await self.handler.processData(id: input.id)
          }
        }
      }
      """
    }
  }

  @Test func internalAccessModifiers() {
    assertMacro {
      """
      @RPC
      internal protocol InternalService {
        internal func fetchData(id: String) async throws -> String
      }
      """
    } expansion: {
      """
      internal protocol InternalService {
        internal func fetchData(id: String) async throws -> String
      }

      private struct InternalServiceInputs {
        struct FetchData: Codable {
          let id: String
        }
      }

      private struct InternalServiceOutputs {
        struct Nothing: Codable {
        }
      }

      struct InternalServiceClient: InternalService, Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func fetchData(id: String) async throws -> String {
          let input = InternalServiceInputs.FetchData(id: id)
          return try await transport.send(
            route: "/fetchData",
            input: input,
            outputType: String.self,
          )
        }
      }

      struct InternalServiceServer<Handler: InternalService & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "fetchData") { (input: InternalServiceInputs.FetchData) in
            try await self.handler.fetchData(id: input.id)
          }
        }
      }
      """
    }
  }

  @Test func publicAccessModifiers() {
    assertMacro {
      """
      @RPC
      public protocol PublicService {
        public func retrieveData(id: String) async throws -> String
      }
      """
    } expansion: {
      """
      public protocol PublicService {
        public func retrieveData(id: String) async throws -> String
      }

      private struct PublicServiceInputs {
        struct RetrieveData: Codable {
          let id: String
        }
      }

      private struct PublicServiceOutputs {
        struct Nothing: Codable {
        }
      }

      public struct PublicServiceClient: PublicService, Sendable {
        private let transport: any RPCTransport

        public init(transport: any RPCTransport) {
          self.transport = transport
        }

        public init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        public func retrieveData(id: String) async throws -> String {
          let input = PublicServiceInputs.RetrieveData(id: id)
          return try await transport.send(
            route: "/retrieveData",
            input: input,
            outputType: String.self,
          )
        }
      }

      public struct PublicServiceServer<Handler: PublicService & Sendable>: RPCServer {
        private let handler: Handler

        public init(handler: Handler) {
          self.handler = handler
        }

        public func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "retrieveData") { (input: PublicServiceInputs.RetrieveData) in
            try await self.handler.retrieveData(id: input.id)
          }
        }
      }
      """
    }
  }

  @Test func packageAccessModifiers() {
    assertMacro {
      """
      @RPC
      package protocol PackageService {
        package func fetchData(id: String) async throws -> String
      }
      """
    } expansion: {
      """
      package protocol PackageService {
        package func fetchData(id: String) async throws -> String
      }

      private struct PackageServiceInputs {
        struct FetchData: Codable {
          let id: String
        }
      }

      private struct PackageServiceOutputs {
        struct Nothing: Codable {
        }
      }

      package struct PackageServiceClient: PackageService, Sendable {
        private let transport: any RPCTransport

        package init(transport: any RPCTransport) {
          self.transport = transport
        }

        package init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        package func fetchData(id: String) async throws -> String {
          let input = PackageServiceInputs.FetchData(id: id)
          return try await transport.send(
            route: "/fetchData",
            input: input,
            outputType: String.self,
          )
        }
      }

      package struct PackageServiceServer<Handler: PackageService & Sendable>: RPCServer {
        private let handler: Handler

        package init(handler: Handler) {
          self.handler = handler
        }

        package func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "fetchData") { (input: PackageServiceInputs.FetchData) in
            try await self.handler.fetchData(id: input.id)
          }
        }
      }
      """
    }
  }

  @Test func optionalParametersWithOptionalReturn() {
    assertMacro {
      """
      struct User: Codable {
        let id: UUID
        let name: String
      }

      @RPC
      protocol OptionalService {
        func greet(name: String?) async throws -> String?
        func processNumbers(numbers: [Int]?) async throws -> [Int]?
        func updateUser(user: User?) async throws -> User?
      }
      """
    } expansion: {
      """
      struct User: Codable {
        let id: UUID
        let name: String
      }
      protocol OptionalService {
        func greet(name: String?) async throws -> String?
        func processNumbers(numbers: [Int]?) async throws -> [Int]?
        func updateUser(user: User?) async throws -> User?
      }

      private struct OptionalServiceInputs {
        struct Greet: Codable {
          let name: String?
        }

        struct ProcessNumbers: Codable {
          let numbers: [Int]?
        }

        struct UpdateUser: Codable {
          let user: User?
        }
      }

      private struct OptionalServiceOutputs {
        struct Nothing: Codable {
        }
      }

      struct OptionalServiceClient: OptionalService, Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func greet(name: String?) async throws -> String? {
          let input = OptionalServiceInputs.Greet(name: name)
          return try await transport.send(
            route: "/greet",
            input: input,
            outputType: String?.self,
          )
        }

        func processNumbers(numbers: [Int]?) async throws -> [Int]? {
          let input = OptionalServiceInputs.ProcessNumbers(numbers: numbers)
          return try await transport.send(
            route: "/processNumbers",
            input: input,
            outputType: [Int]?.self,
          )
        }

        func updateUser(user: User?) async throws -> User? {
          let input = OptionalServiceInputs.UpdateUser(user: user)
          return try await transport.send(
            route: "/updateUser",
            input: input,
            outputType: User?.self,
          )
        }
      }

      struct OptionalServiceServer<Handler: OptionalService & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "greet") { (input: OptionalServiceInputs.Greet) in
            try await self.handler.greet(name: input.name)
          }

          registry.register(method: "processNumbers") { (input: OptionalServiceInputs.ProcessNumbers) in
            try await self.handler.processNumbers(numbers: input.numbers)
          }

          registry.register(method: "updateUser") { (input: OptionalServiceInputs.UpdateUser) in
            try await self.handler.updateUser(user: input.user)
          }
        }
      }
      """
    }
  }

  @Test func multipleOptionalParameters() {
    assertMacro {
      """
      @RPC
      protocol SearchService {
        func search(query: String?, filters: [String]?, limit: Int?) async throws -> [String]
      }
      """
    } expansion: {
      """
      protocol SearchService {
        func search(query: String?, filters: [String]?, limit: Int?) async throws -> [String]
      }

      private struct SearchServiceInputs {
        struct Search: Codable {
          let query: String?
          let filters: [String]?
          let limit: Int?
        }
      }

      private struct SearchServiceOutputs {
        struct Nothing: Codable {
        }
      }

      struct SearchServiceClient: SearchService, Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func search(query: String?, filters: [String]?, limit: Int?) async throws -> [String] {
          let input = SearchServiceInputs.Search(query: query, filters: filters, limit: limit)
          return try await transport.send(
            route: "/search",
            input: input,
            outputType: [String].self,
          )
        }
      }

      struct SearchServiceServer<Handler: SearchService & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "search") { (input: SearchServiceInputs.Search) in
            try await self.handler.search(query: input.query, filters: input.filters, limit: input.limit)
          }
        }
      }
      """
    }
  }

  @Test func inlineServerHandlerDisabled() {
    assertMacro {
      """
      @RPC(inlineHandler: false)
      protocol EchoService {
        func ping(message: String) async throws -> String
      }
      """
    } expansion: {
      """
      protocol EchoService {
        func ping(message: String) async throws -> String
      }

      private struct EchoServiceInputs {
        struct Ping: Codable {
          let message: String
        }
      }

      private struct EchoServiceOutputs {
        struct Nothing: Codable {
        }
      }

      struct EchoServiceClient: EchoService, Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func ping(message: String) async throws -> String {
          let input = EchoServiceInputs.Ping(message: message)
          return try await transport.send(
            route: "/ping",
            input: input,
            outputType: String.self,
          )
        }
      }

      struct EchoServiceServer<Handler: EchoService & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "ping") { (input: EchoServiceInputs.Ping) in
            try await self.handler.ping(message: input.message)
          }
        }
      }
      """
    }
  }

  @Test func inlineServerHandlerEnabled() {
    assertMacro {
      """
      @RPC(inlineHandler: true)
      protocol EchoService {
        func ping(message: String) async throws -> String
      }
      """
    } expansion: {
      """
      protocol EchoService {
        func ping(message: String) async throws -> String
      }

      private struct EchoServiceInputs {
        struct Ping: Codable {
          let message: String
        }
      }

      private struct EchoServiceOutputs {
        struct Nothing: Codable {
        }
      }

      struct EchoServiceClient: EchoService, Sendable {
        private let transport: any RPCTransport

        init(transport: any RPCTransport) {
          self.transport = transport
        }

        init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        func ping(message: String) async throws -> String {
          let input = EchoServiceInputs.Ping(message: message)
          return try await transport.send(
            route: "/ping",
            input: input,
            outputType: String.self,
          )
        }
      }

      struct EchoServiceServer<Handler: EchoService & Sendable>: RPCServer {
        private let handler: Handler

        init(handler: Handler) {
          self.handler = handler
        }

        func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "ping") { (input: EchoServiceInputs.Ping) in
            try await self.handler.ping(message: input.message)
          }
        }
      }

      struct EchoServiceInlineServerHandler: EchoService, Sendable {
        var pingHandler: @Sendable (String) async throws -> String

        func ping(message: String) async throws -> String {
          try await pingHandler(message)
        }
      }

      extension EchoService where Self == EchoServiceInlineServerHandler {
        static func inline(
          ping: @escaping @Sendable (String) async throws -> String,
        ) -> EchoServiceInlineServerHandler {
          EchoServiceInlineServerHandler(
            pingHandler: ping,
          )
        }
      }
      """
    }
  }

  @Test func publicInlineServerHandlerAccessModifiers() {
    assertMacro {
      """
      @RPC(inlineHandler: true)
      public protocol PublicInlineService {
        public func ping(message: String) async throws -> String
      }
      """
    } expansion: {
      """
      public protocol PublicInlineService {
        public func ping(message: String) async throws -> String
      }

      private struct PublicInlineServiceInputs {
        struct Ping: Codable {
          let message: String
        }
      }

      private struct PublicInlineServiceOutputs {
        struct Nothing: Codable {
        }
      }

      public struct PublicInlineServiceClient: PublicInlineService, Sendable {
        private let transport: any RPCTransport

        public init(transport: any RPCTransport) {
          self.transport = transport
        }

        public init(baseURL: URL) {
          self.transport = HTTPTransport(baseURL: baseURL)
        }

        public func ping(message: String) async throws -> String {
          let input = PublicInlineServiceInputs.Ping(message: message)
          return try await transport.send(
            route: "/ping",
            input: input,
            outputType: String.self,
          )
        }
      }

      public struct PublicInlineServiceServer<Handler: PublicInlineService & Sendable>: RPCServer {
        private let handler: Handler

        public init(handler: Handler) {
          self.handler = handler
        }

        public func register(on registry: any RPCHandlerRegistry) {
          registry.register(method: "ping") { (input: PublicInlineServiceInputs.Ping) in
            try await self.handler.ping(message: input.message)
          }
        }
      }

      public struct PublicInlineServiceInlineServerHandler: PublicInlineService, Sendable {
        public var pingHandler: @Sendable (String) async throws -> String

        public func ping(message: String) async throws -> String {
          try await pingHandler(message)
        }
      }

      extension PublicInlineService where Self == PublicInlineServiceInlineServerHandler {
        public static func inline(
          ping: @escaping @Sendable (String) async throws -> String,
        ) -> PublicInlineServiceInlineServerHandler {
          PublicInlineServiceInlineServerHandler(
            pingHandler: ping,
          )
        }
      }
      """
    }
  }
}

@Suite(.macros(["RPC": RPCMacro.self]))
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
      protocol BadService {
        func sync(id: String) -> String
      }
      """
    } diagnostics: {
      """
      @RPC
      protocol BadService {
        func sync(id: String) -> String
             ┬───
             ╰─ 🛑 @RPC: 'sync' must be declared 'async throws'
      }
      """
    }
  }

  @Test func diagnosticOnThrowsOnlyMethod() {
    assertMacro {
      """
      @RPC
      protocol BadService {
        func throwsOnly(id: String) throws -> String
      }
      """
    } diagnostics: {
      """
      @RPC
      protocol BadService {
        func throwsOnly(id: String) throws -> String
             ┬─────────
             ╰─ 🛑 @RPC: 'throwsOnly' must be declared 'async throws'
      }
      """
    }
  }

  @Test func diagnosticOnAsyncOnlyMethod() {
    assertMacro {
      """
      @RPC
      protocol BadService {
        func asyncOnly(id: String) async -> String
      }
      """
    } diagnostics: {
      """
      @RPC
      protocol BadService {
        func asyncOnly(id: String) async -> String
             ┬────────
             ╰─ 🛑 @RPC: 'asyncOnly' must be declared 'async throws'
      }
      """
    }
  }

  @Test func diagnosticOnMethodWithNeitherAsyncNorThrows() {
    assertMacro {
      """
      @RPC
      protocol BadService {
        func regular(id: String) -> String
      }
      """
    } diagnostics: {
      """
      @RPC
      protocol BadService {
        func regular(id: String) -> String
             ┬──────
             ╰─ 🛑 @RPC: 'regular' must be declared 'async throws'
      }
      """
    }
  }

  @Test func diagnosticOnAssociatedType() {
    assertMacro {
      """
      @RPC
      protocol BadService {
        associatedtype Model
      }
      """
    } diagnostics: {
      """
      @RPC
      protocol BadService {
        associatedtype Model
                       ┬────
                       ╰─ 🛑 @RPC: associated type 'Model' is not supported
      }
      """
    }
  }

  @Test func diagnosticOnGenericMethod() {
    assertMacro {
      """
      @RPC
      protocol BadService {
        func fetch<T>(id: String) async throws -> T
      }
      """
    } diagnostics: {
      """
      @RPC
      protocol BadService {
        func fetch<T>(id: String) async throws -> T
             ┬────
             ╰─ 🛑 @RPC: 'fetch' must not be generic
      }
      """
    }
  }

  @Test func diagnosticOnOverloadedMethods() {
    assertMacro {
      """
      @RPC
      protocol BadService {
        func load(id: String) async throws -> String
        func load(name: String) async throws -> String
      }
      """
    } diagnostics: {
      """
      @RPC
      protocol BadService {
        func load(id: String) async throws -> String
             ┬───
             ╰─ 🛑 @RPC: overloaded method 'load' is not supported
        func load(name: String) async throws -> String
             ┬───
             ╰─ 🛑 @RPC: overloaded method 'load' is not supported
      }
      """
    }
  }

  @Test func diagnosticOnUnsupportedParameterShapes() {
    assertMacro {
      """
      @RPC
      protocol BadService {
        func update(value: inout String) async throws
        func log(values: String...) async throws
        func callback(handler: () -> Void) async throws
      }
      """
    } diagnostics: {
      """
      @RPC
      protocol BadService {
        func update(value: inout String) async throws
                           ┬───────────
                           ╰─ 🛑 @RPC: parameter 'value' must not be inout
        func log(values: String...) async throws
                               ┬──
                               ╰─ 🛑 @RPC: parameter 'values' must not be variadic
        func callback(handler: () -> Void) async throws
                               ┬─────────
                               ╰─ 🛑 @RPC: parameter 'handler' must use a Codable-compatible type
      }
      """
    }
  }

  @Test func diagnosticOnInvalidInputTypes() {
    assertMacro {
      """
      @RPC
      protocol BadService {
        func send(
          tuple: (String, Int),
          metatype: User.Type,
          any: Any,
          object: AnyObject,
          selfReference: Self,
          optional: Optional<() -> Void>,
          array: [Any],
          dictionary: [String: Self],
          wrapper: Wrapper<(String, Int)>
        ) async throws
      }
      """
    } diagnostics: {
      """
      @RPC
      protocol BadService {
        func send(
          tuple: (String, Int),
                 ┬────────────
                 ╰─ 🛑 @RPC: parameter 'tuple' must use a Codable-compatible type
          metatype: User.Type,
                    ┬────────
                    ╰─ 🛑 @RPC: parameter 'metatype' must use a Codable-compatible type
          any: Any,
               ┬──
               ╰─ 🛑 @RPC: parameter 'any' must use a Codable-compatible type
          object: AnyObject,
                  ┬────────
                  ╰─ 🛑 @RPC: parameter 'object' must use a Codable-compatible type
          selfReference: Self,
                         ┬───
                         ╰─ 🛑 @RPC: parameter 'selfReference' must use a Codable-compatible type
          optional: Optional<() -> Void>,
                             ┬─────────
                             ╰─ 🛑 @RPC: parameter 'optional' must use a Codable-compatible type
          array: [Any],
                  ┬──
                  ╰─ 🛑 @RPC: parameter 'array' must use a Codable-compatible type
          dictionary: [String: Self],
                               ┬───
                               ╰─ 🛑 @RPC: parameter 'dictionary' must use a Codable-compatible type
          wrapper: Wrapper<(String, Int)>
                           ┬────────────
                           ╰─ 🛑 @RPC: parameter 'wrapper' must use a Codable-compatible type
        ) async throws
      }
      """
    }
  }

  @Test func diagnosticOnInvalidReturnTypes() {
    assertMacro {
      """
      @RPC
      protocol BadService {
        func tuple() async throws -> (String, Int)
        func metatype() async throws -> User.Type
        func any() async throws -> Any
        func object() async throws -> AnyObject
        func selfReference() async throws -> Self
        func optional() async throws -> Optional<() -> Void>
        func array() async throws -> [Any]
        func dictionary() async throws -> [String: Self]
        func wrapper() async throws -> Wrapper<(String, Int)>
      }
      """
    } diagnostics: {
      """
      @RPC
      protocol BadService {
        func tuple() async throws -> (String, Int)
                                     ┬────────────
                                     ╰─ 🛑 @RPC: return type of 'tuple' must be Codable-compatible
        func metatype() async throws -> User.Type
                                        ┬────────
                                        ╰─ 🛑 @RPC: return type of 'metatype' must be Codable-compatible
        func any() async throws -> Any
                                   ┬──
                                   ╰─ 🛑 @RPC: return type of 'any' must be Codable-compatible
        func object() async throws -> AnyObject
                                      ┬────────
                                      ╰─ 🛑 @RPC: return type of 'object' must be Codable-compatible
        func selfReference() async throws -> Self
                                             ┬───
                                             ╰─ 🛑 @RPC: return type of 'selfReference' must be Codable-compatible
        func optional() async throws -> Optional<() -> Void>
                                                 ┬─────────
                                                 ╰─ 🛑 @RPC: return type of 'optional' must be Codable-compatible
        func array() async throws -> [Any]
                                      ┬──
                                      ╰─ 🛑 @RPC: return type of 'array' must be Codable-compatible
        func dictionary() async throws -> [String: Self]
                                                   ┬───
                                                   ╰─ 🛑 @RPC: return type of 'dictionary' must be Codable-compatible
        func wrapper() async throws -> Wrapper<(String, Int)>
                                               ┬────────────
                                               ╰─ 🛑 @RPC: return type of 'wrapper' must be Codable-compatible
      }
      """
    }
  }

  @Test func diagnosticOnMultipleInvalidDefinitions() {
    assertMacro {
      """
      @RPC
      protocol BadService {
        associatedtype Model
        func load<T>(id: Any) -> Self
        func load(id: String) async throws -> String
      }
      """
    } diagnostics: {
      """
      @RPC
      protocol BadService {
        associatedtype Model
                       ┬────
                       ╰─ 🛑 @RPC: associated type 'Model' is not supported
        func load<T>(id: Any) -> Self
                                 ┬───
             │           │       ╰─ 🛑 @RPC: return type of 'load' must be Codable-compatible
                         ┬──
             │           ╰─ 🛑 @RPC: parameter 'id' must use a Codable-compatible type
             ┬───
             ├─ 🛑 @RPC: 'load' must not be generic
             ├─ 🛑 @RPC: 'load' must be declared 'async throws'
             ╰─ 🛑 @RPC: overloaded method 'load' is not supported
        func load(id: String) async throws -> String
             ┬───
             ╰─ 🛑 @RPC: overloaded method 'load' is not supported
      }
      """
    }
  }
}
