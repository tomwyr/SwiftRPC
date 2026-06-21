import Foundation
import SwiftRPC

@RPC
protocol AppService {
  func getUser(id: UUID) async throws -> User
  func listUsers() async throws -> [User]
  func createUser(name: String, email: String) async throws -> User

  func getPost(id: UUID) async throws -> Post
  func createPost(authorId: UUID, title: String, body: String) async throws -> Post
  func deletePost(id: UUID) async throws -> Bool
}

struct User: Codable {
  let id: UUID
  let name: String
  let email: String

  init(id: UUID, name: String, email: String) {
    self.id = id
    self.name = name
    self.email = email
  }
}

struct Post: Codable {
  let id: UUID
  let authorId: UUID
  let title: String
  let body: String

  init(id: UUID, authorId: UUID, title: String, body: String) {
    self.id = id
    self.authorId = authorId
    self.title = title
    self.body = body
  }
}
