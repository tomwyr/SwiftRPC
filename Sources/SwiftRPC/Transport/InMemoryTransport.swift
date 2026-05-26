import Foundation

/// In-memory transport for running both client and server in the same process.
public final class InMemoryTransport: RPCTransport, RPCHandlerRegistry, @unchecked Sendable {
  private var handlers: [String: (Codable) async throws -> Codable] = [:]

  public init() {}

  public func register<Input: Codable & Sendable, Output: Codable & Sendable>(
    method: String,
    handler: @escaping @Sendable (Input) async throws -> Output
  ) {
    handlers[method] = { input in
      guard let typedInput = input as? Input else {
        throw RPCError(
          code: .internalError,
          message: "Expected type \(Input.self) but got \(type(of: input)) for method \(method)",
        )
      }
      return try await handler(typedInput)
    }
  }

  public func send<Input: Codable, Output: Codable>(
    route: String,
    input: Input,
    outputType: Output.Type,
  ) async throws -> Output {
    // Remove leading "/" from route to match registered method name.
    let method = String(route.dropFirst())

    guard let handler = handlers[method] else {
      throw RPCError(code: .internalError, message: "Method not found: \(method)")
    }

    let result: Codable
    do {
      result = try await handler(input)
    } catch let rpcError as RPCError {
      throw rpcError
    } catch {
      throw RPCError(code: .internalError, message: error.outMessage)
    }

    guard let typedOutput = result as? Output else {
      throw RPCError(
        code: .internalError,
        message:
          "Handler returned unexpected type \(type(of: result)), expected \(Output.self) for method \(method)",
      )
    }
    return typedOutput
  }
}

extension Error {
  var outMessage: String {
    (self as? LocalizedError)?.errorDescription ?? "Internal error"
  }
}
