import Foundation

@objc
class ExposedSwiftClass: NSObject {

  @objc
  func exposedMethod(a: Int, b: String?) -> String {
    ""
  }

  @objc
  var exposedProperty: Int

  @objc
  override init() {
    exposedProperty = 2
  }

  @objc
  init(value: Int) {
    exposedProperty = value
  }
}

@objc(RenamedForObjC)
class RenamedExposedSwiftClass: NSObject {

  @objc(property)
  var theProperty: Int

  @objc(action:param:)
  func doAction(a: Int, parm: Int) {
  }

  override init() {
    theProperty = 2
  }
}
