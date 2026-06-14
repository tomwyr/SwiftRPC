import Foundation
import Hummingbird
import Testing

func withTestServer(
  at url: URL,
  configure: (Router<BasicRequestContext>) -> Void,
  body: @escaping @Sendable () async throws -> Void,
) async throws {
  let host = try #require(url.host)
  let port = try #require(url.port)

  let router = Router()
  configure(router)

  let ready = ServerReady()

  let app = Application(
    router: router,
    configuration: .init(address: .hostname(host, port: port)),
    onServerRunning: { _ in await ready.markReady() },
  )

  try await withServerReady(ready: ready) {
    try await app.run()
  } body: {
    try await body()
  }
}

private func withServerReady(
  ready: ServerReady,
  run: @escaping @Sendable () async throws -> Void,
  body: @escaping @Sendable () async throws -> Void,
) async throws {
  let serverTask = Task {
    try await run()
  }

  func stopServer() async {
    serverTask.cancel()
    _ = try? await serverTask.value
  }

  await ready.wait()

  do {
    try await body()
  } catch {
    await stopServer()
    throw error
  }
  await stopServer()
}

private actor ServerReady {
  private var isReady = false
  private var continuation: CheckedContinuation<Void, Never>?

  func wait() async {
    if isReady { return }

    await withCheckedContinuation {
      continuation = $0
    }
  }

  func markReady() {
    guard !isReady else { return }

    isReady = true
    continuation?.resume()
    continuation = nil
  }
}
