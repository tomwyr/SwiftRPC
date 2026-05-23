import Foundation

@testable import SwiftRPC

class MockTransportURLSession: TransportURLSession, @unchecked Sendable {
  var responseHandler: ((URLRequest) throws -> (Data, URLResponse))

  init(responseHandler: @escaping ((URLRequest) throws -> (Data, URLResponse))) {
    self.responseHandler = responseHandler
  }

  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    try responseHandler(request)
  }
}
