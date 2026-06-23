import Testing

@testable import SwiftRPC

@Suite struct RPCServerBuilderTests {
  @Test func singleServer() {
    let servers = buildServers {
      GreetingServiceServer(handler: MockGreetingService(result: "Hello"))
    }

    #expect(servers.count == 1)
  }

  @Test func multipleServers() {
    let servers = buildServers {
      GreetingServiceServer(handler: MockGreetingService(result: "Hello"))
      CounterServiceServer(handler: MockCounterService(result: 42))
    }

    #expect(servers.count == 2)
  }

  @Test func localDeclarations() {
    let servers = buildServers {
      let greeting = MockGreetingService(result: "Hello")
      GreetingServiceServer(handler: greeting)
    }

    #expect(servers.count == 1)
  }

  @Test func optionalServer() {
    let includeCounter = false

    let servers = buildServers {
      GreetingServiceServer(handler: MockGreetingService(result: "Hello"))

      if includeCounter {
        CounterServiceServer(handler: MockCounterService(result: 42))
      }
    }

    #expect(servers.count == 1)
    #expect(servers.first is GreetingServiceServer<MockGreetingService>)
  }

  @Test func conditionalServer() {
    let useCounter = true

    let servers = buildServers {
      if useCounter {
        CounterServiceServer(handler: MockCounterService(result: 42))
      } else {
        GreetingServiceServer(handler: MockGreetingService(result: "Hello"))
      }
    }

    #expect(servers.count == 1)
    #expect(servers.first is CounterServiceServer<MockCounterService>)
  }

  @Test func serverLoop() {
    let serverGroups: [[any RPCServer]] = [
      [GreetingServiceServer(handler: MockGreetingService(result: "Hello"))],
      [CounterServiceServer(handler: MockCounterService(result: 42))],
    ]

    let servers = buildServers {
      for group in serverGroups {
        for server in group {
          server
        }
      }
    }

    #expect(servers.count == 2)
  }

  private func buildServers(
    @RPCServerBuilder _ servers: () -> [any RPCServer]
  ) -> [any RPCServer] {
    servers()
  }
}
