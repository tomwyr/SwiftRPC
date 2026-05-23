import Foundation
import Hummingbird
import SwiftRPC

/// Hummingbird implementation of RPCHandlerRegistry.
/// Handles HTTP-specific details like request parsing and response formatting.
struct HummingbirdHandlerRegistry<Context: RequestContext>:
  RPCHandlerRegistry, @unchecked Sendable
{
  let router: any RouterMethods<Context>

  init(router: any RouterMethods<Context>) {
    self.router = router
  }

  func register<Input: Codable & Sendable, Output: Codable & Sendable>(
    method: String,
    handler: @escaping @Sendable (Input) async throws -> Output,
  ) {
    router.post("/\(method)") { request, context -> Response in
      let envelope = try await request.decode(
        as: RPCRequest<Input>.self,
        context: context,
      )
      let input = envelope.input
      do {
        let result = try await handler(input)
        let response = RPCResponse<Output>.success(result)
        return try context.responseEncoder.encode(response, from: request, context: context)
      } catch let rpcError as RPCError {
        let response = RPCResponse<Output>.failure(rpcError)
        return try context.responseEncoder.encode(response, from: request, context: context)
      } catch {
        let rpcError = RPCError(code: .internalError, message: error.outMessage)
        let response = RPCResponse<Output>.failure(rpcError)
        return try context.responseEncoder.encode(response, from: request, context: context)
      }
    }
  }
}

/// Namespace for convenient registration with Hummingbird routers.
extension RPCServer {
  /// Register this server directly on a Hummingbird router
  public func register<Context: RequestContext>(on router: any RouterMethods<Context>) {
    self.register(on: HummingbirdHandlerRegistry(router: router))
  }
}

extension Error {
  var outMessage: String {
    (self as? LocalizedError)?.errorDescription ?? "Internal error"
  }
}
