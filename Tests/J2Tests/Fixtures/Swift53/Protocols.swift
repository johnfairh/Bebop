/// A protocol.
public protocol FirstProtocol {
  /// Brief note about m
  ///
  /// What m is all about.
  /// - parameter arg: The argument
  /// - returns: The answer
  func m(arg: Int) -> String

  associatedtype AssocType
  func assocFunc() -> AssocType

  var getOnly: Int { get }

  var setAndGet: Int { get set }
}

extension FirstProtocol {
  /// A protocol extension method
  func e() {}
}

extension FirstProtocol {
  /// Return a safe default.
  ///
  /// There's more: it's the empty string.
  func m(arg: Int) -> String {
    ""
  }
}

protocol P1 {}
protocol P2 {}

struct S1: P1 {}

extension S1: CustomStringConvertible {
  var description: String { "" }
}

struct S2<T>: P1 where T: Equatable {
  func equatables2() {}
}

extension S2: P2 where T: Comparable {
  func comparables2() {}
}

extension S2: Equatable where T: Equatable {
  func equatables22() {}
}

extension Dictionary: P2 {}

extension Array: P1 where Element: Comparable {
  func arrayFunc() {}
}
