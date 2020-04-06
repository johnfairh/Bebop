/// Main structure
public struct SpmSwiftModule {
    // MARK: Fields
    public var text = "Hello, World!"

    // MARK: _Nested_ strúctures ``

    public struct Nested1 { 
      public struct Nested2a {
      }
      @available(*, deprecated)
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
    /// Third & Fourth cases - `second`
    case third, fourth
    /// Fifth case
    case fifth(a: String,_ b: Int)
}

/// - parameters:
///    - arg1: Number one
///    - arg2: Second
///    - arg3: Third
///
/// See `SpmSwiftModule` -- or `SpmSwiftModule.ABaseClass`.
@available(iOS 9, macOS 10.12, *)
public func functionA(arg1: Int,
                      _ arg2: Int,
                      arg3 argMeaning: Int) {
}

/// A deprecated function
///
/// - parameter callback: The callback
/// - returns: A string
@available(iOS, deprecated: 12.0.1, message: "Deprecated!", renamed: "functionA(arg1:_:arg3:)")
@available(macOS, deprecated: 10.14, message: "Deprecated on *macOS* too")
public func deprecatedFunction(callback: (_ report: String) -> Int) -> String {
  return ""
}

/// A base class
public class ABaseClass {
  public init() {}

  public convenience init(a: Int) { self.init() }

  deinit {}
  /// Base class docs for `method(param:)`
  public func method(param: Int) -> String {
    return ""
  }

  public static func staticMethod() -> Int {
    return 2
  }

  public subscript(arg: String) -> Int {
    get {
      return 0
    }
    set {
    }
  }

  public static subscript(arg: String) -> Int {
    return 0
  }

  public class subscript(arg: Int) -> String {
    return ""
  }
}

struct T {
}

/// A derived class
public class ADerivedClass<T, Q: Sequence>: ABaseClass {
  var t: Q? = nil

  /// See `ABaseClass.method(...)`.
  public override func method(param: Int) -> String {
    return ""
  }

  public func generic(param: T) -> T {
    return param
  }
}
