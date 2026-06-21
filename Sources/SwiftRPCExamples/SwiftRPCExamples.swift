import Foundation

@main
struct SwiftRPCExamples {
  static func main() async throws {
    let arguments = CommandLine.arguments

    guard arguments.count > 1 else {
      printUsage()
      exit(1)
    }

    switch Array(arguments.dropFirst()) {
    case ["in-memory"]:
      try await InMemoryApp.run()
    case ["hummingbird", "server"]:
      try await HummingbirdServerExample.run()
    case ["hummingbird", "client"]:
      try await HummingbirdClientExample.run()
    case ["vapor", "server"]:
      try await VaporServerExample.run()
    case ["vapor", "client"]:
      try await VaporClientExample.run()
    default:
      printUsage()
      exit(1)
    }
  }

  private static func printUsage() {
    print(
      """
      Usage:
        swift run SwiftRPCExamples in-memory
        swift run SwiftRPCExamples hummingbird server
        swift run SwiftRPCExamples hummingbird client
        swift run SwiftRPCExamples vapor server
        swift run SwiftRPCExamples vapor client
      """
    )
  }
}
