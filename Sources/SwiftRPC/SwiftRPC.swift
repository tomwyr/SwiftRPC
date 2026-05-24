@attached(peer, names: suffixed(Client), suffixed(Server), suffixed(Inputs), suffixed(Outputs))
public macro RPC() = #externalMacro(module: "SwiftRPCMacros", type: "RPCMacro")
