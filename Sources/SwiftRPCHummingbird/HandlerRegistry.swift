import Foundation
import Hummingbird
import SwiftRPC

/// Hummingbird implementation of RPCHandlerRegistry.
/// Handles HTTP-specific details like request parsing and response formatting.
public struct HummingbirdHandlerRegistry<Context: RequestContext>:
  RPCHandlerRegistry, @unchecked Sendable
{
  let router: any RouterMethods<Context>

  public init(router: any RouterMethods<Context>) {
    self.router = router
  }

  @preconcurrency
  public func register<Input: Codable & Sendable, Output: Codable & Sendable>(
    method: String,
    handler: @escaping @Sendable (Input) async throws -> Output
  ) {
    router.post("/\(method)") { request, context -> Response in
      let envelope = try await request.decode(
        as: RPCRequest<Input>.self,
        context: context
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
        let rpcError = RPCError(code: .internalError, message: error.localizedDescription)
        let response = RPCResponse<Output>.failure(rpcError)
        return try context.responseEncoder.encode(response, from: request, context: context)
      }
    }
  }
}
