@discardableResult
@available(*, deprecated)
public func withoutDocComment() -> Int { 3 }

/// Doc comment means we can get the @available!
@discardableResult
@available(*, deprecated)
public func withDocComment() -> Int { 1 }
