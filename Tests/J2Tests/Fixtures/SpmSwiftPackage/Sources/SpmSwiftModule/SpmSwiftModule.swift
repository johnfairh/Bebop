///
public struct SpmSwiftModule {
    public var text = "Hello, World!"
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
@available(*, deprecated, message: "Has always been deprecated")
public func deprecatedFunction(callback: (_ report: String) -> Int) -> String {
  return ""
}
