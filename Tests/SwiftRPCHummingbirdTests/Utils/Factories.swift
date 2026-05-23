import Foundation
import Hummingbird
import HummingbirdTesting
import SwiftRPC

func rpcEncode<Input: Codable>(_ input: Input) throws -> Data {
  try JSONEncoder().encode(RPCRequest(input: input))
}

func rpcDecode<Output: Codable>(
  _ buffer: ByteBuffer, into: Output.Type = Output.self,
) throws -> RPCResponse<Output> {
  try JSONDecoder().decode(RPCResponse<Output>.self, from: buffer)
}
