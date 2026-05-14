import Foundation

@main
struct SwiftRPCExamples {
  static func main() async throws {
    let arguments = CommandLine.arguments

    guard arguments.count > 1 else {
      print("Usage: SwiftRPCExamples <client|server>")
      exit(1)
    }

    let mode = arguments[1]

    switch mode {
    case "client":
      try await ClientApp.run()
    case "server":
      try await ServerApp.run()
    default:
      print("Usage: SwiftRPCExamples <client|server>")
      exit(1)
    }
  }
}