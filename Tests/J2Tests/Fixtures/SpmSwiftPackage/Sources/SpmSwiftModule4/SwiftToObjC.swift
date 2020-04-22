import Foundation

@objc
public class ExposedSwiftClass: NSObject {

  @objc
  public func exposedMethod(a: Int, b: String?) -> String {
    ""
  }

  @objc
  public var exposedProperty: Int

  @objc
  public override init() {
    exposedProperty = 2
  }

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
