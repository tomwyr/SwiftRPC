@attached(peer, names: suffixed(Client), suffixed(Server), suffixed(Inputs))
public macro RPC() = #externalMacro(module: "SwiftRPCMacros", type: "RPCMacro")
