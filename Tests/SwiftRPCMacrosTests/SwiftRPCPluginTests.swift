import SwiftSyntaxMacros
import Testing

@testable import SwiftRPCMacros

@Suite
struct SwiftRPCPluginTests {
  @Test func declaredMacros() {
    let macros = SwiftRPCPlugin().providingMacros
    #expect(macros.containsExactly([RPCMacro.self]))
  }
}

extension Array where Element == any Macro.Type {
  private var uniqueIdentifiers: Set<ObjectIdentifier> {
    Set(map(ObjectIdentifier.init))
  }

  func containsExactly(_ types: [any Macro.Type]) -> Bool {
    count == types.count && uniqueIdentifiers == types.uniqueIdentifiers
  }
}
