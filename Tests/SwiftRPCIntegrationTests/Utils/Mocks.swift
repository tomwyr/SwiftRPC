import Foundation

class MockUserService: UserService, @unchecked Sendable {
  var logInCalls = 0
  var logInParams = [String]()
  var logOutCalls = 0
  var createCalls = 0
  var createResults = [UserProfile]()
  var deleteCalls = 0

  func logIn(password: String) async throws -> UserActionResult {
    logInCalls += 1
    logInParams.append(password)
    return .success
  }

  func logOut() async throws -> Int {
    logOutCalls += 1
    return 1
  }

  func create() async throws -> UserProfile {
    createCalls += 1
    guard !createResults.isEmpty else {
      return UserProfile(
        userId: UUID(),
        fullName: "DefaultUser",
        accountSettings: AccountSettings(privateProfile: false, maxFollowers: 100, contentLanguage: "en"),
        accountTypes: [.standard]
      )
    }
    return createResults.removeFirst()
  }

  func delete(user: UserProfile) async throws -> Bool {
    deleteCalls += 1
    return true
  }
}
