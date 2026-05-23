import Foundation

struct TestInput: Codable, Equatable {
  let id: UUID
  let name: String
  let value: Int
}

struct TestOutput: Codable, Equatable {
  let result: String
  let timestamp: Int
}

struct EmptyInput: Codable, Equatable {}

struct EmptyOutput: Codable, Equatable {}

enum TestEnum: String, Codable, Equatable {
  case optionA
  case optionB
  case optionC
}

struct NestedStruct: Codable, Equatable {
  let id: UUID
  let title: String
  let nested: InnerStruct
  let items: [TestEnum]
}

struct InnerStruct: Codable, Equatable {
  let innerValue: String
  let innerArray: [Int]
}

struct TestError: LocalizedError {
  let message: String

  var errorDescription: String? { message }
}

struct TestUnknownError: Error {}
