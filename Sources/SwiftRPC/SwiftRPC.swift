@attached(
  peer,
  names: suffixed(Client), suffixed(Server),
  suffixed(InlineServerHandler), suffixed(Inputs), suffixed(Outputs)
)
@attached(extension, names: named(inline))
public macro RPC(inlineHandler: Bool = false) =
  #externalMacro(module: "SwiftRPCMacros", type: "RPCMacro")
