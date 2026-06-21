import Foundation
import SwiftRPC
import Vapor

/// Vapor implementation of RPCHandlerRegistry.
/// Handles HTTP-specific details like request parsing and response formatting.
struct VaporHandlerRegistry: RPCHandlerRegistry {
  let routes: any RoutesBuilder

  init(routes: any RoutesBuilder) {
    self.routes = routes
  }

  func register<Input: Codable & Sendable, Output: Codable & Sendable>(
    method: String,
    handler: @escaping @Sendable (Input) async throws -> Output,
  ) {
    routes.post([.constant(method)]) { request async throws -> Response in
      let envelope: RPCRequest<Input>
      do {
        envelope = try request.content.decode(RPCRequest<Input>.self)
      } catch {
        throw Abort(.badRequest, reason: "Invalid RPC request body")
      }
      let input = envelope.input
      do {
        let result = try await handler(input)
        let response = RPCResponse<Output>.success(result)
        return try encode(response, for: request)
      } catch let rpcError as RPCError {
        let response = RPCResponse<Output>.failure(.rpc(rpcError))
        return try encode(response, for: request)
      } catch let serviceError as RPCServiceErrorEnvelope {
        let response = RPCResponse<Output>.failure(.service(serviceError))
        return try encode(response, for: request)
      } catch {
        let rpcError = RPCError(code: .internalError, message: error.outMessage)
        let response = RPCResponse<Output>.failure(.rpc(rpcError))
        return try encode(response, for: request)
      }
    }
  }
}

private func encode<Output: Codable>(
  _ response: RPCResponse<Output>,
  for request: Request,
) throws -> Response {
  let httpResponse = Response(status: .ok)
  try httpResponse.content.encode(response, as: .json)
  return httpResponse
}

/// Namespace for convenient registration with Vapor routes.
extension RPCServer {
  /// Register this server directly on Vapor routes.
  public func register(on routes: any RoutesBuilder) {
    self.register(on: VaporHandlerRegistry(routes: routes))
  }
}
