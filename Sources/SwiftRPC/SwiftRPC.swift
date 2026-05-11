@attached(peer, names: suffixed(Client), suffixed(Server))
public macro RPC() = #externalMacro(module: "SwiftRPCMacros", type: "RPCMacro")
