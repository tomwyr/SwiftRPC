import Foundation
import Hummingbird
import HummingbirdTesting

actor Counter {
  var value = 0

  func increment() {
    value += 1
  }
}
