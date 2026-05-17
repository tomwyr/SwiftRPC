import Foundation
import Testing

@testable import SwiftRPC

@Suite struct SwiftRPCTests {
  @Test func errorDescriptionDisplaysUserFacingMessage() {
    let notFoundError = RPCError(code: .notFound, message: "Resource not found")
    #expect(notFoundError.errorDescription == "[NOT_FOUND] Resource not found")

    let badRequestError = RPCError(code: .badRequest, message: "Invalid input")
    #expect(badRequestError.errorDescription == "[BAD_REQUEST] Invalid input")

    let internalError = RPCError(code: .internalError, message: "Server error occurred")
    #expect(internalError.errorDescription == "[INTERNAL_ERROR] Server error occurred")
  }
}