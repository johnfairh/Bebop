/// A class to demonstrate the separate-child style.
///
/// Below the methods have their description but an
/// entire page of their own.  The autolinking should
/// work in both places.
public class Layout {
  /// See `b()`
  ///
  /// Real information about `a()`.
  public func a() {}

  /// See `a()`
  ///
  /// Real information about `b()`.
  public func b() {}
}

/// A class to demonstrate link rewriting.
///
/// [See the guide](Guide.md)
public class LinkRewrite {
  /// Here is a picture
  ///
  /// Basic link to media:
  ///
  /// ![See spot run](bird.jpg)
  ///
  /// Link to media with resize and title:
  /// ![See spot run|200x200](bird.jpg "is it a plane?")
  ///
  /// Link to media with resize, scale, no title:
  /// ![See spot run|200x200,30%](bird.jpg)
  public func spot() {}
}
