import Foundation

/// Stores a handler for same-process RPC calls between a server and client.
public final class InMemoryHandlerRegistry: RPCHandlerRegistry {
  private var handlers: [String: InMemoryHandler] = [:]

  /// Creates an empty in-memory handler registry.
  public init() {}

  /// Registers a handler for an RPC method.
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
}

/// In-memory transport for running both client and server in the same process.
public struct InMemoryTransport: RPCTransport {
  private let handlers: [String: InMemoryHandler]

  /// Creates a transport from the handlers currently stored in a registry.
  public init(from registry: InMemoryHandlerRegistry) {
    self.handlers = registry.handlersSnapshot
  }

  /// Sends an in-memory RPC request to a registered method handler.
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

private typealias InMemoryHandler = @Sendable (Codable) async throws -> Codable

extension InMemoryHandlerRegistry {
  fileprivate var handlersSnapshot: [String: InMemoryHandler] {
    handlers
  }
}

extension Error {
  var outMessage: String {
    (self as? LocalizedError)?.errorDescription ?? "Internal error"
  }
}
