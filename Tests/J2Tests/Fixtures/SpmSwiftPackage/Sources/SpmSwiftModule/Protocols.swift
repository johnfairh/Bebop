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

public protocol SecondProtocol: FirstProtocol {
  func secondProtocolMethod() -> String
}

extension SecondProtocol {
  /// A default implementation for a method of `FirstProtocol`
  /// provided by `SecondProtocol`.
  /// From source we mess this up as an extension method.
  /// From symbolgraph we mess this up as being part of `FirstProtocol`.
  var getOnly: Int { 3 }
}

