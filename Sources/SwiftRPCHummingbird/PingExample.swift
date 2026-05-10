import Foundation
import Hummingbird
import SwiftRPC

@RPC
public protocol EchoRouter: Sendable {
  func ping(message: String) async throws -> String
}

struct EchoRouterServerHandler: EchoRouter {
  func ping(message: String) async throws -> String {
    "Hi"
  }
}

// public struct EchoRouterClient: Sendable {
//   private let transport: any RPCTransport

//   public init(transport: any RPCTransport) {
//     self.transport = transport
//   }

//   public init(baseURL: URL) {
//     self.transport = HTTPTransport(baseURL: baseURL)
//   }

//   private struct _PingInput: Codable {
//     let message: String
//   }

//   public func ping(message: String) async throws -> String {
//     let input = _PingInput(message: message)
//     return try await transport.send(
//       route: "/ping",
//       input: input,
//       outputType: String.self
//     )
//   }
// }

// public struct EchoRouterServer<Handler: EchoRouter & Sendable>: Sendable {
//   private let handler: Handler
//   private let encoder: JSONEncoder
//   private let decoder: JSONDecoder

//   public init(
//     handler: Handler,
//     encoder: JSONEncoder = JSONEncoder(),
//     decoder: JSONDecoder = JSONDecoder()
//   ) {
//     self.handler = handler
//     self.encoder = encoder
//     self.decoder = decoder
//   }

//   private struct _PingInput: Codable {
//     let message: String
//   }

//   /// Register all RPC routes onto a Hummingbird Router.
//   public func register<Context: RequestContext>(on router: some RouterMethods<Context>) {
//     router.post("/ping") { request, context -> Response in
//       let envelope = try await request.decode(
//         as: RPCRequest<_PingInput>.self,
//         using: decoder
//       )
//       let input = envelope.input
//       do {
//         let result = try await self.handler.ping(message: input.message)
//         let response = RPCResponse<String>.success(result)
//         return try Response.json(response, encoder: encoder)
//       } catch let rpcError as RPCError {
//         let response = RPCResponse<String>.failure(rpcError)
//         return try Response.json(response, encoder: encoder, status: .internalServerError)
//       } catch {
//         let rpcError = RPCError(code: .internalError, message: error.localizedDescription)
//         let response = RPCResponse<String>.failure(rpcError)
//         return try Response.json(response, encoder: encoder, status: .internalServerError)
//       }
//     }
//   }
// }
