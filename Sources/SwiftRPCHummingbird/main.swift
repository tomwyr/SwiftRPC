import Foundation
import Hummingbird

let command = CommandLine.arguments.dropFirst().first

switch command {
case "client":
  try await runClient()
case "server":
  try await runServer()
default:
  print("Unknown command: \(String(describing: command))")
}

func runClient() async throws {
  let client = EchoRouterClient(baseURL: URL(string: "http://127.0.0.1:8080")!)

  let message = "Hello"
  print("Sending:", message)

  let answer = try await client.ping(message: message)
  print("Received:", answer)
}

func runServer() async throws {
  let router = Router()
  let server = EchoRouterServer(handler: EchoRouterServerHandler())
  server.register(on: router)

  let app = Application(router: router)
  print("Running server")
  try await app.runService()
}
