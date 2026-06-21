import Foundation
import SwiftRPC

enum ExampleScenario {
  static func run(client: AppServiceClient) async throws {
    print("Creating user...")
    let alice = try await client.createUser(name: "Alice", email: "alice@example.com")
    print("Created: \(alice.name) [\(alice.id)]")

    print("\nListing users...")
    let users = try await client.listUsers()
    users.forEach { print("  - \($0.name) <\($0.email)>") }

    print("\nFetching user by id...")
    let fetched = try await client.getUser(id: alice.id)
    print("Fetched: \(fetched.name)")

    print("\nCreating post...")
    let post = try await client.createPost(
      authorId: alice.id,
      title: "Hello SwiftRPC",
      body: "Type-safe RPC in Swift, no code generation step required."
    )
    print("Created post: \(post.title) [\(post.id)]")

    print("\nDeleting post...")
    let deleted = try await client.deletePost(id: post.id)
    print("Deleted: \(deleted)")

    print("\nFetching non-existent user (should throw RPCError)...")
    do {
      _ = try await client.getUser(id: UUID())
    } catch let error as RPCError {
      print("Caught RPCError [\(error.code.rawValue)]: \(error.message)")
    }
  }
}
