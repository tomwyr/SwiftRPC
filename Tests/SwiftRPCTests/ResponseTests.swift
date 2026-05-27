import Foundation
import Testing

@testable import SwiftRPC

@Suite struct ResponseTests {
  @Test func encodeNilOptional() throws {
    let response = RPCResponse<String?>.success(nil)
    let encoder = JSONEncoder()

    let data = try encoder.encode(response)
    let jsonString = String(data: data, encoding: .utf8)!

    #expect(jsonString.contains("ok"))
  }

  @Test func encodeNonNullOptional() throws {
    let response = RPCResponse<String?>.success("value")
    let encoder = JSONEncoder()

    let data = try encoder.encode(response)
    let jsonString = String(data: data, encoding: .utf8)!

    #expect(jsonString.contains("ok"))
  }

  @Test func decodeNilOptional() throws {
    let jsonString = #"{"ok":null}"#
    let data = jsonString.data(using: .utf8)!

    let decoder = JSONDecoder()
    let response = try decoder.decode(RPCResponse<String?>.self, from: data)

    switch response {
    case .success(let value):
      #expect(value == nil)
    case .failure:
      Issue.record("Expected success but got failure")
    }
  }

  @Test func decodeEmptyResponse() throws {
    let jsonString = #"{}"#
    let data = jsonString.data(using: .utf8)!

    let decoder = JSONDecoder()

    #expect(throws: DecodingError.self) {
      try decoder.decode(RPCResponse<String>.self, from: data)
    }
  }
}