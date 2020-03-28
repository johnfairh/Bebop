//
//  Topic.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// A section on a page that contains multiple items.
///
/// Topics generated from source MARK comments, or by j2 per-kind, or per constrainted extension,
/// or from a custom_groups config stanza.
public final class Topic: Equatable, Encodable, CustomStringConvertible {
    /// Topic title
    public private(set) var title: RichText
    /// Short version of the title, used for the aux nav menu
    public private(set) var _menuTitle: RichText?
    /// User-provided blurb about the topic.  From custom_groups.
    public private(set) var overview: RichText?
    /// Source of the topic.  Mostly for debug?
    public private(set) var kind: TopicKind
    /// Constrained extension requirements when the user has overwritten the auto-topic...
    private var savedRequirements: SwiftGenericReqs?

    public var menuTitle: RichText {
        _menuTitle ?? title
    }

    public var description: String {
        "[Topic: \(title.plainText.first!.value)]"
    }

    /// Initialize from a pragma/MARK in source code or static string (will be treated as markdown)
    public init(title: String = "") {
        self.title = RichText(title)
        self.overview = nil
        self.kind = .sourceMark
    }

    /// Initialize from a custom topic definition
    public init(title: Localized<String>, overview: Localized<String>? = nil) {
        self.title = RichText(title)
        self.overview = overview.flatMap { RichText($0) }
        self.kind = .custom
    }

    /// Initialize from a def-kind topic
    public init(defTopic: DefTopic) {
        self.title = RichText(defTopic.name)
        self.kind = .defTopic
    }

    /// Initialize for an ObjC Category
    public init(categoryName: ObjCCategoryName) {
        self.title = RichText(categoryName.categoryName)
        self.kind = .category
    }

    /// Initialize from some generic constraints
    public convenience init(requirements: SwiftGenericReqs) {
        self.init()
        self.kind = .genericRequirements
        setFrom(requirements: requirements)
    }

    private final func setFrom(requirements: SwiftGenericReqs) {
        title = requirements.richLong
        _menuTitle = requirements.richShort
    }

    /// Make a user mark remember a generic requirements marker
    public func makeGenericRequirement(requirements: SwiftGenericReqs) {
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

    public var genericRequirements: String {
        precondition(kind == .genericRequirements)
        if let savedRequirements = savedRequirements {
            return savedRequirements.text
        }
        return title.markdown.first!.value.md
    }

    /// Format the topic's content
    func format(formatters: RichText.Formatters) {
        title.format(formatters.inline)
        _menuTitle?.format(formatters.inline)
        overview?.format(formatters.block)
    }

    /// Not sure what stops this from being auto-generated.
    public static func == (lhs: Topic, rhs: Topic) -> Bool {
        lhs.title == rhs.title &&
            lhs.overview == rhs.overview &&
            lhs.kind == rhs.kind
    }
}

public enum TopicKind: String, Equatable, Encodable {
    /// MARK: comment or #pragma mark
    case sourceMark
    /// ObjC category
    case category
    /// Swift constrained extension
    case genericRequirements
    /// custom_groups
    case custom
    /// 'Types' 'Methods' etc.
    case defTopic
}
