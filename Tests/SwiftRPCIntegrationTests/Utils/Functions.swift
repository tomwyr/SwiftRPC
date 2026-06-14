import Foundation
import Hummingbird
import Testing

func withTestServer(
  at url: URL,
  configure: @escaping @Sendable (Router<BasicRequestContext>) -> Void,
  body: @escaping @Sendable () async throws -> Void,
) async throws {
  let serverStartup = ReadyCheck()

  try await withThrowingTaskGroup(of: Void.self) { group in
    group.addTask {
      try await runTestServer(
        at: url, configure: configure,
        onReady: { await serverStartup.ready() },
      )
    }

    group.addTask {
      try await serverStartup.wait()
      try await body()
    }

    // Wait for either the body or server to finish first, then cancel the
    // other task so neither side waits indefinitely.
    defer { group.cancelAll() }
    try await group.next()
  }
}

private func runTestServer(
  at url: URL,
  configure: @escaping @Sendable (Router<BasicRequestContext>) -> Void,
  onReady: @escaping @Sendable () async -> Void
) async throws {

  let host = try #require(url.host)
  let port = try #require(url.port)

  let router = Router()
  configure(router)

  let app = Application(
    router: router,
    configuration: .init(address: .hostname(host, port: port)),
    onServerRunning: { _ in await onReady() },
  )

  try await app.run()
}

private actor ReadyCheck {
  private var isReady = false
  private var continuation: CheckedContinuation<Void, any Error>?

  func wait() async throws {
    guard !isReady else { return }

    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation {
        self.continuation = $0
      }
    } onCancel: {
      // Cancelling the task does not resume the stored continuation.
      // Resume it from the actor so wait() can return.
      Task { await cancelWait() }
    }
  }

  func ready() {
    guard !isReady else { return }

    isReady = true
    continuation?.resume()
    continuation = nil
  }

  private func cancelWait() {
    continuation?.resume(throwing: CancellationError())
    continuation = nil
  }
}
