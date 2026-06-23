import Foundation

@testable import SwiftRPC

@RPC
protocol GreetingService {
  func greet(name: String) async throws -> String
}

@RPC
protocol CounterService {
  func double(value: Int) async throws -> Int
}
