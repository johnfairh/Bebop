public class PodClass {
  var count: Int

  init() {
    count = 1
  }

  @available(macOS, unavailable)
  func onlyForIOS() {}

  @available(iOS, unavailable)
  func onlyForMacOS() {}
}
