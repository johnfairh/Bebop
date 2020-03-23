//
//  Topic.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

public final class Topic: Equatable, Encodable, CustomStringConvertible {
    public private(set) var title: RichText
    public private(set) var _menuTitle: RichText?
    public private(set) var body: RichText?
    public private(set) var kind: TopicKind
    private var savedRequirements: String?

    public var menuTitle: RichText {
        _menuTitle ?? title
    }

    public var description: String {
        "[Topic: \(title.plainText.first!.value)]"
    }

    /// Initialize from a pragma/MARK in source code or static string (will be treated as markdown)
    public init(title: String = "") {
        self.title = RichText(title)
        self.body = nil
        self.kind = .sourceMark
    }

    /// Initialize from a custom topic definition
    public init(title: Localized<String>, body: Localized<String>? = nil) {
        self.title = RichText(title)
        self.body = body.flatMap { RichText($0) }
        self.kind = .custom
    }

    /// Initialize from a def-kind topic
    public init(defTopic: DefTopic) {
        self.title = RichText(defTopic.name)
        self.body = nil
        self.kind = .defTopic
    }

    /// Initialize for an ObjC Category
    public init(categoryName: ObjCCategoryName) {
        self.title = RichText(categoryName.categoryName)
        self.body = nil
        self.kind = .category
    }

    /// Initialize from some generic constraints
    public convenience init(requirements: String) {
        self.init()
        self.kind = .genericRequirements
        setFrom(requirements: requirements)
    }

    private final func setFrom(requirements: String) {
        let markdown = requirements.re_sub(#"[\w\.]+"#, with: #"`$0`"#)
        title = RichText(.localizedOutput(.availableWhere, markdown))
        _menuTitle = RichText(.localizedOutput(.availableWhereShort, markdown))
        body = nil
    }

    /// Make a user mark remember a generic requirements marker
    public func makeGenericRequirement(requirements: String) {
        kind = .genericRequirements
        savedRequirements = requirements
    }

    /// Flip a user mark back to the generic version
    public func useAsGenericRequirement() {
        if let savedRequirements = savedRequirements {
            setFrom(requirements: savedRequirements)
            self.savedRequirements = nil
        }
    }

    var genericRequirements: String {
        precondition(kind == .genericRequirements)
        if let savedRequirements = savedRequirements {
            return savedRequirements
        }
        return title.markdown.first!.value.md
    }

    /// Format the topic's content
    public func format(_ formatter: RichText.Formatter) rethrows {
        try title.format(formatter)
        try _menuTitle?.format(formatter)
        try body?.format(formatter)
    }

    /// Not sure what stops this from being auto-generated.
    public static func == (lhs: Topic, rhs: Topic) -> Bool {
        lhs.title == rhs.title &&
            lhs.body == rhs.body &&
            lhs.kind == rhs.kind
    }
}

public enum TopicKind: String, Equatable, Encodable {
    case sourceMark
    case category
    case genericRequirements
    case custom
    case defTopic
}
