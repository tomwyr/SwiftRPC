@attached(peer, names: suffixed(Client), suffixed(Server), named(Inputs), named(Outputs))
public macro RPC() = #externalMacro(module: "SwiftRPCMacros", type: "RPCMacro")
