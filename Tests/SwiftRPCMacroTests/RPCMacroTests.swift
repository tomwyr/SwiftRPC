import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import SwiftRPCMacros

final class RPCMacroTests: XCTestCase {
    let macros: [String: any Macro.Type] = ["RPC": RPCMacro.self]

    func testSingleMethodExpansion() {
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
                    private let encoder: JSONEncoder
                    private let decoder: JSONDecoder

                    public init(
                        handler: Handler,
                        encoder: JSONEncoder = JSONEncoder(),
                        decoder: JSONDecoder = JSONDecoder()
                    ) {
                        self.handler = handler
                        self.encoder = encoder
                        self.decoder = decoder
                    }

                private struct _PingInput: Codable {
                    let message: String
                }

                    /// Register all RPC routes onto a Hummingbird Router.
                    public func register<Context: RequestContext>(on router: some RouterMethods<Context>) {
                router.post("/ping") { request, context -> Response in
                    let envelope = try await request.decode(
                        as: RPCRequest<_PingInput>.self,
                        using: decoder
                    )
                    let input = envelope.input
                    do {
                        let result = try await self.handler.ping(message: input.message)
                        let response = RPCResponse<String>.success(result)
                        return try Response.json(response, encoder: encoder)
                    } catch let rpcError as RPCError {
                        let response = RPCResponse<String>.failure(rpcError)
                        return try Response.json(response, encoder: encoder, status: .internalServerError)
                    } catch {
                        let rpcError = RPCError(code: .internalError, message: error.localizedDescription)
                        let response = RPCResponse<String>.failure(rpcError)
                        return try Response.json(response, encoder: encoder, status: .internalServerError)
                    }
                }
                    }
                }
                """,
            macros: macros,
        )
    }

    func testMultipleParametersWrappedIntoInputStruct() {
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
                    private let encoder: JSONEncoder
                    private let decoder: JSONDecoder

                    public init(
                        handler: Handler,
                        encoder: JSONEncoder = JSONEncoder(),
                        decoder: JSONDecoder = JSONDecoder()
                    ) {
                        self.handler = handler
                        self.encoder = encoder
                        self.decoder = decoder
                    }

                private struct _CreatePostInput: Codable {
                    let title: String
                    let body: String
                    let authorId: UUID
                }

                    /// Register all RPC routes onto a Hummingbird Router.
                    public func register<Context: RequestContext>(on router: some RouterMethods<Context>) {
                router.post("/createPost") { request, context -> Response in
                    let envelope = try await request.decode(
                        as: RPCRequest<_CreatePostInput>.self,
                        using: decoder
                    )
                    let input = envelope.input
                    do {
                        let result = try await self.handler.createPost(title: input.title, body: input.body, authorId: input.authorId)
                        let response = RPCResponse<Post>.success(result)
                        return try Response.json(response, encoder: encoder)
                    } catch let rpcError as RPCError {
                        let response = RPCResponse<Post>.failure(rpcError)
                        return try Response.json(response, encoder: encoder, status: .internalServerError)
                    } catch {
                        let rpcError = RPCError(code: .internalError, message: error.localizedDescription)
                        let response = RPCResponse<Post>.failure(rpcError)
                        return try Response.json(response, encoder: encoder, status: .internalServerError)
                    }
                }
                    }
                }
                """,
            macros: macros,
        )
    }

    func testNoParameterMethod() {
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

                private struct _PingInput: Codable {
                }

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
                    private let encoder: JSONEncoder
                    private let decoder: JSONDecoder

                    public init(
                        handler: Handler,
                        encoder: JSONEncoder = JSONEncoder(),
                        decoder: JSONDecoder = JSONDecoder()
                    ) {
                        self.handler = handler
                        self.encoder = encoder
                        self.decoder = decoder
                    }

                private struct _PingInput: Codable {
                }

                    /// Register all RPC routes onto a Hummingbird Router.
                    public func register<Context: RequestContext>(on router: some RouterMethods<Context>) {
                router.post("/ping") { request, context -> Response in
                    let envelope = try await request.decode(
                        as: RPCRequest<_PingInput>.self,
                        using: decoder
                    )
                    let input = envelope.input
                    do {
                        let result = try await self.handler.ping()
                        let response = RPCResponse<String>.success(result)
                        return try Response.json(response, encoder: encoder)
                    } catch let rpcError as RPCError {
                        let response = RPCResponse<String>.failure(rpcError)
                        return try Response.json(response, encoder: encoder, status: .internalServerError)
                    } catch {
                        let rpcError = RPCError(code: .internalError, message: error.localizedDescription)
                        let response = RPCResponse<String>.failure(rpcError)
                        return try Response.json(response, encoder: encoder, status: .internalServerError)
                    }
                }
                    }
                }
                """,
            macros: macros,
        )
    }

    func testDiagnosticOnNonProtocol() {
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
                    message: "@RPC can only be applied to a protocol", line: 1, column: 1)
            ],
            macros: macros,
        )
    }

    func testDiagnosticOnNonAsyncThrowsMethod() {
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
                    message: "@RPC: 'sync' must be declared 'async throws'", line: 1, column: 1)
            ],
            macros: macros,
        )
    }
}
