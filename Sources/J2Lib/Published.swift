//
//  Published.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

// MARK: Interface

struct PublishedModule {
    let name: String
    let groupPolicy: ModuleGroupPolicy
    let sourceDirectory: URL?
    let codeHostURL: Localized<String>?
    let codeHostFilePrefix: String?

    init(name: String,
         groupPolicy: ModuleGroupPolicy = .global,
         sourceDirectory: URL? = nil,
         codeHostURL: Localized<String>? = nil,
         codeHostFilePrefix: String? = nil) {
        self.name = name
        self.groupPolicy = groupPolicy
        self.sourceDirectory = sourceDirectory
        self.codeHostURL = codeHostURL
        self.codeHostFilePrefix = codeHostFilePrefix
    }
}

/// Repo of options, derivations, and services that have cross-component dependencies.
/// Originally hoped this need could be avoided but reality got in the way.
/// We're committed to the pure-instance component design (except where we're not...)
/// which leads to this double-sided discovery design.  Sucks.
protocol Published {
    /// Used when parsing YAML fragments.  This is the base for any relative filesystem
    /// URLs, ie. the location of the config file.
    var configRelativePathBaseURL: URL { get }

    /// Default language of the docs
    var defaultLanguage: DefLanguage { get }

    /// Configured author name
    var authorName: Localized<String>? { get }

    /// Configured child item style
    var childItemStyle: ChildItemStyle { get }

    /// List of excluded ACLs, human-readable
    var excludedACLs: String { get }

    /// Source order mode
    var sourceOrderDefs: Bool { get }

    /// Modules - valid post-Gather
    var modules: [PublishedModule] { get }

    /// Code-host URL for non-modular pages
    var codeHostFallbackURL: Localized<String>? { get }

    /// Overall version number string
    var moduleVersion: String? { get }

    /// The doc-root relative path of a named piece of media, or `nil` if there is none.
    func urlPathForMedia(_ name: String) -> String?

    /// The doc-root relative path of a named guide, or `nil` if there is none.
    func urlPathForGuide(_ name: String) -> String?

    /// The URL to use linking an item's location to its source code, or `nil` if not possible
    func codeHostItemURLForLocation(_ location: DefLocation) -> String?
}

extension Published {
    /// Helper, are we in multi-module mode?  Invalid before Gather completes.
    var isMultiModule: Bool { modules.count > 1 }

    /// All the modules being worked on.  Empty before Gather completes.
    var moduleNames: [String] {
        modules.map(\.name)
    }

    /// Info about some module.  Module name must be known.
    func module(_ name: String) -> PublishedModule {
        modules.first(where: { $0.name == name })!
    }
}

// MARK: Concrete

final class PublishStore: Published {
    var configRelativePathBaseURL: URL { _configRelativePathBaseURL! }
    private var _configRelativePathBaseURL: URL?
    func setConfigRelativePathBaseURL(_ url: URL) {
        _configRelativePathBaseURL = url
    }

    var defaultLanguage: DefLanguage = .swift

    var authorName: Localized<String>?

    var childItemStyle: ChildItemStyle = .nested

    var excludedACLs: String = ""

    var sourceOrderDefs: Bool = false

    var modules: [PublishedModule] = [] {
        didSet {
            modules.sort(by: { $0.name < $1.name })
        }
    }

    var moduleVersion: String?

    private var rootCodeHostURL: Localized<String>? // spose its an href rather than a url...
    func setRootCodeHostURL(url: Localized<String>?) {
        rootCodeHostURL = url
    }
    var codeHostFallbackURL: Localized<String>? {
        if let rootCodeHostURL = rootCodeHostURL {
            return rootCodeHostURL
        }
        if let someModuleCodeHostURL = modules.compactMap(\.codeHostURL).first {
            return someModuleCodeHostURL
        }
        return nil
    }

    func urlPathForMedia(_ name: String) -> String? { _urlPathForMedia(name) }
    private var _urlPathForMedia: (String) -> String? = { a in nil }
    func registerURLPathForMedia(_ callback: @escaping (String) -> String?) {
        _urlPathForMedia = callback
    }

    func urlPathForGuide(_ name: String) -> String? { _urlPathForGuide(name) }
    private var _urlPathForGuide: (String) -> String? = { a in nil }
    func registerURLPathForGuide(_ callback: @escaping (String) -> String?) {
        _urlPathForGuide = callback
    }

    func codeHostItemURLForLocation(_ location: DefLocation) -> String? {
        _codeHostItemURLForLocation(location)
    }
    private var _codeHostItemURLForLocation: (DefLocation) -> String? = { a in nil }
    func registerCodeHostItemURLForLocation(_ callback: @escaping (DefLocation) -> String?) {
        _codeHostItemURLForLocation = callback
    }
}
