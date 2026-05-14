import Foundation
import Hummingbird
import SwiftRPC
import SwiftRPCHummingbird

struct ServerApp {
  static func run() async throws {
    let handler = AppRouterHandler()

    let router = Router()

    let registry = HummingbirdHandlerRegistry(router: router)
    AppRouterServer(handler: handler).register(on: registry)

    let app = Application(
      router: router,
      configuration: .init(address: .hostname("0.0.0.0", port: 8080)),
    )

    print("Server starting on http://0.0.0.0:8080")
    try await app.runService()
  }
}

actor AppRouterHandler: AppRouter {
  private var users = [UUID: User]()
  private var posts = [UUID: Post]()

  func getUser(id: UUID) async throws -> User {
    guard let user = users[id] else {
      throw RPCError(code: .notFound, message: "User \(id) not found")
    }
    return user
  }

  func listUsers() async throws -> [User] {
    Array(users.values).sorted { $0.name < $1.name }
  }

  func createUser(name: String, email: String) async throws -> User {
    guard !name.isEmpty, !email.isEmpty else {
      throw RPCError(code: .badRequest, message: "name and email are required")
    }
    let user = User(id: UUID(), name: name, email: email)
    users[user.id] = user
    return user
  }

  func getPost(id: UUID) async throws -> Post {
    guard let post = posts[id] else {
      throw RPCError(code: .notFound, message: "Post \(id) not found")
    }
    return post
  }

  func createPost(authorId: UUID, title: String, body: String) async throws -> Post {
    guard users[authorId] != nil else {
      throw RPCError(code: .notFound, message: "Author \(authorId) not found")
    }
    let post = Post(id: UUID(), authorId: authorId, title: title, body: body)
    posts[post.id] = post
    return post
  }

  func deletePost(id: UUID) async throws -> Bool {
    guard posts[id] != nil else {
      throw RPCError(code: .notFound, message: "Post \(id) not found")
    }
    posts.removeValue(forKey: id)
    return true
  }
}
