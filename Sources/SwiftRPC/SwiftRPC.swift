@attached(
  peer,
  names: suffixed(Client), suffixed(Server),
  suffixed(InlineServerHandler), suffixed(Inputs), suffixed(Outputs)
)
@attached(extension, names: named(inline))
public macro RPC(
  inlineHandler: Bool = false,
  varargMaxArity: Int = 10,
  varargOverflowBehavior: RPCVarargOverflowBehavior = .reject,
) =
  #externalMacro(module: "SwiftRPCMacros", type: "RPCMacro")

/// Controls how generated servers handle variadic argument lists above `varargMaxArity`.
public enum RPCVarargOverflowBehavior: Sendable {
  /// Fail the RPC call when the argument count exceeds `varargMaxArity`.
  case reject

  /// Ignore arguments after `varargMaxArity` and call the handler with the retained prefix.
  case truncate
}
