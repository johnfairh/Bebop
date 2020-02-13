/// Main structure
public struct SpmSwiftModule {
    // MARK: Fields
    public var text = "Hello, World!"

    // MARK: _Nested_ strúctures

    public struct Nested1 { 
      public struct Nested2a {
      }
      public struct Nested2b {
      }
    }

    public struct Nested2 {}
}

/// An enum
public enum AnEnum {
    /// First case
    case first(Int)
    /// Second case
    case second
    /// Third & Fourth cases
    case third, fourth
}

@available(iOS 9, macOS 10.12, *)
public func functionA(arg1: Int,
                      _ arg2: Int,
                      arg3 argMeaning: Int) {
}

/// A deprecated function
///
/// - parameter callback: The callback
/// - returns: A string
@available(iOS, deprecated: 12.0, message: "Deprecated!")
@available(macOS, deprecated: 10.14, message: "Deprecated on macOS too")
public func deprecatedFunction(callback: (_ report: String) -> Int) -> String {
  return ""
}
