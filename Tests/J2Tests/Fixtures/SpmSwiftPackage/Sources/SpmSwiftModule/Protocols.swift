/// A protocol.
protocol FirstProtocol {
  /// Brief note about m
  ///
  /// What m is all about.
  /// - parameter arg: The argument
  /// - returns: The answer
  func m(arg: Int) -> String

  associatedtype AssocType
  func assocFunc() -> AssocType
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
