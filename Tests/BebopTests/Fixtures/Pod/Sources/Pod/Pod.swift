public class PodClass {
  var count: Int

  init() {
    count = 1
  }

  @available(macOS, unavailable)
  func onlyForIOS() {}

  @available(iOS, unavailable)
  func onlyForMacOS() {}

  @available(*, deprecated, message: "This is deprecated everywhere")
  func globallyDeprecated() {}

  @available(iOS, deprecated, message: "Deprecated only on iOS")
  func iosDeprecated() {}
}
