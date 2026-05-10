import Foundation
import SwiftRPC

// These must be Codable so they can travel across the wire.
public struct User: Codable, Sendable {
  public let id: UUID
  public let name: String
  public let email: String

  public init(id: UUID, name: String, email: String) {
    self.id = id
    self.name = name
    self.email = email
  }
}

public struct Post: Codable, Sendable {
  public let id: UUID
  public let authorId: UUID
  public let title: String
  public let body: String

  public init(id: UUID, authorId: UUID, title: String, body: String) {
    self.id = id
    self.authorId = authorId
    self.title = title
    self.body = body
  }
}

// @RPC generates at compile time:
//
//   AppRouterClient  — concrete struct, call it from iOS/macOS/CLI
//   AppRouterServer  — generic struct, register(on:) to wire up Hummingbird
//
// Route convention:  POST /<methodName>
// Request body:      { "input": { ...parameters... } }
// Response body:     { "ok": <value> }  |  { "error": { "code": "...", "message": "..." } }

@RPC
public protocol AppRouter {
  func getUser(id: UUID) async throws -> User
  func listUsers() async throws -> [User]
  func createUser(name: String, email: String) async throws -> User

  func getPost(id: UUID) async throws -> Post
  func createPost(authorId: UUID, title: String, body: String) async throws -> Post
  func deletePost(id: UUID) async throws -> Bool
}
