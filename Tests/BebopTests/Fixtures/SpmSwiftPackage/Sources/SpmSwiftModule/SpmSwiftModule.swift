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

    /// A pair of Ints
    var a: Int,
        b: Int

    /// A method with params, throws, returns.
    ///
    /// Does some checking.
    ///
    /// - parameter name: The name
    /// - returns: A value
    /// - throws: An error from `AnEnum` if things are wrong
    public func checkState(name: String) throws -> Int {
        2
    }
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
@available(tvOS, unavailable, message: "Not available on the big screen.")
public func functionA(arg1: Int,
                      _ arg2: Int,
                      arg3 argMeaning: Int) {
}

/// A deprecated function
///
/// - parameter callback: The callback
/// - returns: A string
@available(iOS, deprecated: 12.0, message: "Deprecated!")
@available(macOS, deprecated: 10.14, message: "Deprecated on *macOS* too")
@available(*, deprecated)
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

  static var aStaticVar: Int {
    3
  }

  /// An operator!
  public static func +(lhs: ABaseClass, rhs: ABaseClass) -> ABaseClass {
    ABaseClass()
  }
}

struct T {
}

/// Unscoped operator
func +(lhs: T, rhs: T) -> String {
  ""
}

/// A derived class
public class ADerivedClass<T, Q: Sequence>: ABaseClass {
  var t: Q? = nil

  /// See `ABaseClass.method(...)`.
  public override func method(param: Int) -> String {
    return ""
  }

  public func generic(param: T) where T: Equatable {}

  public func generic2<R>(param: T, my param2: R) -> T
    where R: Sequence, R.Element: FirstProtocol {
    return param
  }
}

@propertyWrapper
struct Nop {
    var wrappedValue: String

    init(wrappedValue: String) {
        self.wrappedValue = wrappedValue
    }
}

/// See `@Nop`.
struct PropertyWrapperClient {
    @Nop
    var v: String
}
