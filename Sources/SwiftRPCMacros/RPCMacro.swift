import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct RPCMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext,
    ) throws -> [DeclSyntax] {
        guard let proto = declaration.as(ProtocolDeclSyntax.self) else {
            throw RPCMacroError.notAProtocol
        }

        let methods = try proto.memberBlock.members.compactMap { member -> RPCMethod? in
            guard let fn = member.decl.as(FunctionDeclSyntax.self) else { return nil }
            return try RPCMethod(from: fn)
        }

        let protoName = proto.name.text

        let clientDecl = try makeClient(protoName: protoName, methods: methods)
        let serverDecl = try makeServer(protoName: protoName, methods: methods)

        return [clientDecl, serverDecl]
    }
}

struct RPCMethod {
    let name: String
    let params: [(label: String, name: String, type: String)]
    let returnType: String

    init(from fn: FunctionDeclSyntax) throws {
        name = fn.name.text

        guard let effect = fn.signature.effectSpecifiers,
            effect.asyncSpecifier != nil,
            effect.throwsSpecifier != nil
        else {
            throw RPCMacroError.methodMustBeAsyncThrows(name: fn.name.text)
        }

        params = fn.signature.parameterClause.parameters.map { param in
            let label = param.firstName.text
            let name = param.secondName?.text ?? label
            let type = param.type.trimmedDescription
            return (label: label, name: name, type: type)
        }

        guard let fnReturnType = fn.signature.returnClause?.type.trimmedDescription else {
            throw RPCMacroError.methodMustReturnValue(name: fn.name.text)
        }
        returnType = fnReturnType
    }

    /// The internal input struct name, e.g. `_GetUserInput`
    var inputTypeName: String {
        "_\(name.prefix(1).uppercased())\(name.dropFirst())Input"
    }

    /// The route path, e.g. `/getUser`
    var route: String { "/\(name)" }
}

private func makeClient(protoName: String, methods: [RPCMethod]) throws -> DeclSyntax {
    let clientName = "\(protoName)Client"

    var methodDecls = [String]()
    var inputStructDecls = [String]()

    for method in methods {
        let fields = method.params
            .map { "    let \($0.name): \($0.type)" }
            .joined(separator: "\n")
        let inputStruct = """
            private struct \(method.inputTypeName): Codable {
            \(fields)
            }
            """
        inputStructDecls.append(inputStruct)

        let paramList = method.params
            .map { "\($0.label): \($0.type)" }
            .joined(separator: ", ")
        let inputInit = method.params
            .map { "\($0.name): \($0.name)" }
            .joined(separator: ", ")

        let methodBody = """
            public func \(method.name)(\(paramList)) async throws -> \(method.returnType) {
                let input = \(method.inputTypeName)(\(inputInit))
                return try await transport.send(
                    route: "\(method.route)",
                    input: input,
                    outputType: \(method.returnType).self
                )
            }
            """
        methodDecls.append(methodBody)
    }

    let allInputStructs = inputStructDecls.joined(separator: "\n\n")
    let allMethods = methodDecls.joined(separator: "\n\n")

    let source = """
        public struct \(clientName): Sendable {
            private let transport: any RPCTransport

            public init(transport: any RPCTransport) {
                self.transport = transport
            }

            public init(baseURL: URL) {
                self.transport = HTTPTransport(baseURL: baseURL)
            }

        \(allInputStructs)

        \(allMethods)
        }
        """

    return DeclSyntax(stringLiteral: source)
}

private func makeServer(protoName: String, methods: [RPCMethod]) throws -> DeclSyntax {
    let serverName = "\(protoName)Server"

    var inputStructDecls = [String]()
    var routeRegistrations = [String]()

    for method in methods {
        let fields = method
            .params.map { "    let \($0.name): \($0.type)" }
            .joined(separator: "\n")
        let inputStruct = """
            private struct \(method.inputTypeName): Codable {
            \(fields)
            }
            """
        inputStructDecls.append(inputStruct)

        // Argument forwarding: handler.getUser(id: input.id, ...)
        let callArgs = method.params
            .map { "\($0.label): input.\($0.name)" }
            .joined(separator: ", ")

        let registration = """
            router.post("\(method.route)") { request, context -> Response in
                let envelope = try await request.decode(
                    as: RPCRequest<\(method.inputTypeName)>.self,
                    using: decoder
                )
                let input = envelope.input
                do {
                    let result = try await self.handler.\(method.name)(\(callArgs))
                    let response = RPCResponse<\(method.returnType)>.success(result)
                    return try Response.json(response, encoder: encoder)
                } catch let rpcError as RPCError {
                    let response = RPCResponse<\(method.returnType)>.failure(rpcError)
                    return try Response.json(response, encoder: encoder, status: .internalServerError)
                } catch {
                    let rpcError = RPCError(code: .internalError, message: error.localizedDescription)
                    let response = RPCResponse<\(method.returnType)>.failure(rpcError)
                    return try Response.json(response, encoder: encoder, status: .internalServerError)
                }
            }
            """
        routeRegistrations.append(registration)
    }

    let allInputStructs = inputStructDecls.joined(separator: "\n\n")
    let allRoutes = routeRegistrations.joined(separator: "\n\n")

    let source = """
        public struct \(serverName)<Handler: \(protoName)>: Sendable {
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

        \(allInputStructs)

            /// Register all RPC routes onto a Hummingbird Router.
            public func register<Context: RequestContext>(on router: some RouterMethods<Context>) {
        \(allRoutes)
            }
        }
        """

    return DeclSyntax(stringLiteral: source)
}

enum RPCMacroError: Error, CustomStringConvertible {
    case notAProtocol
    case methodMustBeAsyncThrows(name: String)
    case methodMustReturnValue(name: String)

    var description: String {
        switch self {
        case .notAProtocol:
            "@RPC can only be applied to a protocol"
        case .methodMustBeAsyncThrows(let name):
            "@RPC: '\(name)' must be declared 'async throws'"
        case .methodMustReturnValue(let name):
            "@RPC: '\(name)' must have a return type"
        }
    }
}
