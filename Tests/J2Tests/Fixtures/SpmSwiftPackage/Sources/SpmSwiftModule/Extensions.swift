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
  func doCodability() {}
}

extension GenericBase where T: Equatable,
                            T: FirstProtocol {
  func doFirstMagic() {}

  func doMoreMagic() {}
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
