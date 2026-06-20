import Foundation
import Testing

@testable import SwiftRPC

@Suite struct RPCErrorTests {
  @Test func coreErrorDescription() {
    let notFoundError = RPCError(code: .notFound, message: "Resource not found")
    #expect(notFoundError.errorDescription == "[NOT_FOUND] Resource not found")

    let badRequestError = RPCError(code: .badRequest, message: "Invalid input")
    #expect(badRequestError.errorDescription == "[BAD_REQUEST] Invalid input")

    let internalError = RPCError(code: .internalError, message: "Server error occurred")
    #expect(internalError.errorDescription == "[INTERNAL_ERROR] Server error occurred")
  }

  @Test func coreErrorCoding() throws {
    let failure = RPCResponseError.core(RPCError(code: .badRequest, message: "Invalid input"))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    let data = try encoder.encode(failure)
    let json = try #require(String(data: data, encoding: .utf8))
    #expect(json == #"{"code":"BAD_REQUEST","message":"Invalid input","type":"core"}"#)

    let decoded = try JSONDecoder().decode(RPCResponseError.self, from: data)

    switch decoded {
    case .core(let error):
      #expect(error.code == .badRequest)
      #expect(error.message == "Invalid input")
    case .service:
      Issue.record("Expected core failure but got service failure")
    }
  }

  @Test func serviceErrorCoding() throws {
    let serviceError = UserError.rejected(reason: "No")
    let failure = RPCResponseError.service(RPCServiceErrorEnvelope(serviceError))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    let data = try encoder.encode(failure)
    let json = try #require(String(data: data, encoding: .utf8))
    #expect(json == #"{"payload":{"rejected":{"reason":"No"}},"type":"service"}"#)

    let responseData = Data(#"{"error":\#(json)}"#.utf8)
    let decoded = try JSONDecoder().decode(
      RPCTypedResponse<String, UserError>.self,
      from: responseData,
    )

    switch decoded {
    case .success:
      Issue.record("Expected failure but got success")
    case .failure(.core):
      Issue.record("Expected service failure but got core failure")
    case .failure(.service(let error)):
      #expect(error == serviceError)
    }
  }

  @Test func invalidServiceErrorPayload() {
    let data = Data(#"{"error":{"type":"service","payload":"not a payload"}}"#.utf8)

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(RPCTypedResponse<String, UserError>.self, from: data)
    }
  }

  @Test func serviceErrorWithoutType() {
    let data = Data(#"{"payload":"bm90IGEgcGF5bG9hZA=="}"#.utf8)

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(RPCResponseError.self, from: data)
    }
  }

  @Test func coreErrorWithoutType() {
    let data = Data(#"{"code":"NOT_FOUND","message":"Missing"}"#.utf8)

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(RPCResponseError.self, from: data)
    }
  }
}
