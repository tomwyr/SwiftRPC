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

  let app = Application(
    router: router,
    configuration: .init(address: .hostname(host, port: port)),
  )

  try await withThrowingTaskGroup(of: Void.self) { group in
    group.addTask { try await app.run() }
    group.addTask { try await body() }
    try await group.next()
    group.cancelAll()
  }
}
