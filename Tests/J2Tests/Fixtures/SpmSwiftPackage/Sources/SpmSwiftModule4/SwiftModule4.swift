import SpmObjCModule

extension NormalClass {
  /// Normal class swift method
  ///
  /// See `Kitchen`
  func normal() {}
}

extension Kitchen {
  /// renamed class swift method
  func renamed() {}
}

extension String {
  /// From an external type that doesn't exist in ObjC
  func externalTypeMethod() {}
}
