class GenericBase<T> {
  var boxed: T
  init(type: T) {
    boxed = type
  }

  func mutify() -> T {
    return boxed
  }
}

extension GenericBase where T: Codable {
  var codableCount: Int {
    return 22
  }
  func doCodability() {}
}

extension GenericBase where T: Equatable,
                            T: FirstProtocol {
  func doFirstMagic() {}

  func doMoreMagic() {}
}

extension GenericBase where T: Hashable {
  // MARK: User-custom mark
  func doHashable() {}
}

// MARK: CustomStringConvertible
extension GenericBase : CustomStringConvertible {
  var description: String {
    return ""
  }
}

extension Collection where Element: FirstProtocol {
  func collectEmAll() {}
}

extension Collection where Element == SpmSwiftModule.Nested1 {
  func nestEmAll() {}
}

extension FirstProtocol where AssocType: Hashable {
  func extHashableMethod() {}

  /// Special default implementation for m in Hashable case.
  func m(arg: Int) -> String {
    return ""
  }
}

/// Extension of a nested type from an external module
extension String.Element {
   /// documented method
  func method1() {}
  // undocumented method
  func method2() {}
}

extension StringProtocol {
  func f() {}
  // Default impl that we can't decode
  func hasSuffix(_ prefix: String) -> Bool { false }
}
