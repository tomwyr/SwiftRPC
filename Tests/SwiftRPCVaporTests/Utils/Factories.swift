import Foundation
import SwiftRPC
import Vapor

func rpcEncode<Input: Codable>(_ input: Input) throws -> ByteBuffer {
  let data = try JSONEncoder().encode(RPCRequest(input: input))
  return ByteBuffer(data: data)
}

func rpcDecode<Output: Codable>(
  _ buffer: ByteBuffer, into: Output.Type = Output.self,
) throws -> RPCResponse<Output> {
  try JSONDecoder().decode(RPCResponse<Output>.self, from: Data(buffer.readableBytesView))
}
