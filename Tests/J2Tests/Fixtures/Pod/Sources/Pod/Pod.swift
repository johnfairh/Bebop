public class PodClass {
  var count: Int

  init() {
    count = 1
  }

  @available(iOS 12, *)
  func onlyForIOS() {}

  @available(macOS 10.13, *)
  func onlyForMacOS() {}
}
