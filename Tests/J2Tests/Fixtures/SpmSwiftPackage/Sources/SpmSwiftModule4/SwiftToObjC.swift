import Foundation

@objc
public class ExposedSwiftClass: NSObject {

  /// docs
  @objc
  public func exposedMethod(a: Int, b: String?) -> String {
    ""
  }

  /// docs
  @objc
  public var exposedProperty: Int

  /// ref docs
  @objc
  public var exposedRefProperty: ExposedSwiftClass?

  /// inh init docs
  @objc
  public override init() {
    exposedProperty = 2
    exposedRefProperty = nil
  }

  /// init docs
  @objc
  public init(value: Int) {
    exposedProperty = value
  }
}

@objc(RenamedForObjC)
public class RenamedExposedSwiftClass: NSObject {

  @objc(property)
  public var theProperty: Int

  @objc(action:param:)
  public func doAction(a: Int, parm: Int) {
  }

  public override init() {
    theProperty = 2
  }
}
