/// Should be included in docs
open class PublicClass {
  /// Should not be included in docs
  func internalMethod() {
  }

  /// Should not be included in docs
  /// :nodoc:
  public func hiddenPublicMethod() {
  }
}

/// Should not be included
fileprivate struct PrivateStruct {
  let a: Int
}

/// Should not be included in docs
private protocol PrivateProtocol {
  func privateProtocolMethod()
}

/// Should be included
public protocol PublicProtocol {
  /// Should be included
  func publicProtocolMethod()
}

/// Should not be included in docs
extension PublicClass : PrivateProtocol {
  func privateProtocolMethod() {}
}

/// Should be included
extension PublicClass : PublicProtocol {
  public func publicProtocolMethod() {
  }
}

/// Should not be included
extension PrivateStruct: PrivateProtocol {
  func privateProtocolMethod() {}
}

/// Should be included
extension PublicClass: CustomStringConvertible {
  public var description: String { "" }
}
