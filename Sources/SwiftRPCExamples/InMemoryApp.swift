import Foundation
import SwiftRPC

struct InMemoryApp {
  static func run() async throws {
    let transport = InMemoryTransport()

    // Register the server on the transport
    let server = AppServiceServer(handler: AppServiceHandler())
    server.register(on: transport)

    // Create the client with the same transport
    let client = AppServiceClient(transport: transport)

    print("=== In-Memory Client-Server Running ===\n")

    // --- Create a user ---
    print("Creating user...")
    let alice = try await client.createUser(name: "Alice", email: "alice@example.com")
    print("Created: \(alice.name) [\(alice.id)]")

    // --- List users ---
    print("\nListing users...")
    let users = try await client.listUsers()
    users.forEach { print("  - \($0.name) <\($0.email)>") }

    // --- Get user by id ---
    print("\nFetching user by id...")
    let fetched = try await client.getUser(id: alice.id)
    print("Fetched: \(fetched.name)")

    // --- Create a post ---
    print("\nCreating post...")
    let post = try await client.createPost(
      authorId: alice.id,
      title: "Hello SwiftRPC",
      body: "Type-safe RPC in Swift, no code generation step required."
    )
    print("Created post: \(post.title) [\(post.id)]")

    // --- Delete the post ---
    print("\nDeleting post...")
    let deleted = try await client.deletePost(id: post.id)
    print("Deleted: \(deleted)")

    // --- Error handling ---
    print("\nFetching non-existent user (should throw RPCError)...")
    do {
      _ = try await client.getUser(id: UUID())
    } catch let error as RPCError {
      print("Caught RPCError [\(error.code.rawValue)]: \(error.message)")
    }
  }
}
