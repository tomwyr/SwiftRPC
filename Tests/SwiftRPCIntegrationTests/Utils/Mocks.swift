import Foundation

class MockTestService: TestService, @unchecked Sendable {
  var logInCalls = 0
  var logInParams = [String]()
  var logOutCalls = 0
  var registerCalls = 0
  var registerResults = [TestUser]()
  var unregisterCalls = 0

  func logIn(password: String) async throws -> TestActionResult {
    logInCalls += 1
    logInParams.append(password)
    return .success
  }

  func logOut() async throws -> TestActionResult {
    logOutCalls += 1
    return .success
  }

  func register() async throws -> TestUser {
    registerCalls += 1
    guard !registerResults.isEmpty else {
      return TestUser(id: UUID(), name: "DefaultUser")
    }
    return registerResults.removeFirst()
  }

  func unregister(user: TestUser) async throws -> TestActionResult {
    unregisterCalls += 1
    return .success
  }
}
