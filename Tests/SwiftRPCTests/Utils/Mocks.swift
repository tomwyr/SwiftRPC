import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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

struct MockGreetingService: GreetingService {
  let result: String

  func greet(name: String) async throws -> String {
    result
  }
}

struct MockCounterService: CounterService {
  let result: Int

  func double(value: Int) async throws -> Int {
    result
  }
}
