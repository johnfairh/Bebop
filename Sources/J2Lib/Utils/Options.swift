//
//  Options.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import Yams

// Disappointing to write this all but need
// - distributed options
// - config/response file -> CLI overwrite
// - don't touch my stderr/communicate in English/crash the program
//
// All very custom for what we need.  Provides:
// - bool / string / enum / path / glob decode and validate
// - lists via repeated opts or inline
// - short/long/yaml opts
// - auto-gen of --[no-] -style longopts
// - auto unique-prefix expansion for longopts

// MARK: Flag string manipulation

private extension String {
    var isFlag: Bool {
        hasPrefix("-")
    }

    var isLongFlag: Bool {
        hasPrefix("--")
    }

    var asLongFlag: String {
        "--\(self)"
    }

    var asShortFlag: String {
        "-\(self)"
    }

    var invertedLongFlag: String {
        hasPrefix("--no-") ? re_sub("^--no-", with: "--")
                           : re_sub("^--", with: "--no-")
    }

    var invertableLongFlagSyntax: String {
        re_sub("^--(no-)?", with: "--[no-]")
    }

    var withoutFlagPrefix: String {
        re_sub("^-*", with: "")
    }
}

// MARK: Abstract Option Types

/// Base type of an option
enum OptType {
    /// yes/no, implied by option name alone
    case bool
    /// some text, following option name/keyed in the file.  May repeat/be an array.
    case string
    /// filesystem path that may point to a file/directory, made absolute if necessary
    /// relative to current directory or the location of the config file.
    case path
    /// a string with an absolute path as `path` containing * ?, for matching.
    case glob
    /// an arbitrary yaml structure, not on the CLI
    case yaml
}

/// Models an option accepted by the program and its configured value.
///
/// Supplied by components and then filled in by `OptsParser`.
///
/// We solve this problem in a fairly brutish way, avoiding protocols with associated types and
/// visitors for simplicity, at the expense of some ugly abstract-base-type methods here.
///
class Opt {
    /// Single-character flag.  Includes leading hyphen.
    let shortFlag: String?
    /// Multiple-character flag.  Includes leading hyphens.
    let longFlag: String?
    let yamlKey: String?

    /// Localized help text for the option.  Includes default behaviour.
    let help: String

    /// A string-based opt may repeat.  This means:
    /// * Its flag may occur multiple times on the CLI, all values are collected.
    /// * The flag value may use , to separate items.
    /// * It may refer to an array of values in the config file.  All values are collected.
    ///
    /// It's a user error to repeat a non-repeating option, or to ref an array in the config
    /// file that contains more than one value.
    var repeats: Bool { false }

    /// Boolean options with long flag names are invertable by default
    var isInvertable: Bool { type == .bool }

    /// At least one of `longFlagName` and `yamlKey` must be set.
    /// Don't include "-" at the start of flag names.
    init(s shortFlagName: String? = nil, l longFlagName: String? = nil, y yamlKey: String? = nil, help: String) {
        precondition(longFlagName != nil || yamlKey != nil, "Opt must have a long name somewhere")
        shortFlagName.flatMap { precondition(!$0.isFlag, "Option names don't include the hyphen") }
        longFlagName.flatMap { precondition(!$0.isFlag, "Option names don't include the hyphen") }
        self.shortFlag = shortFlagName.flatMap { $0.asShortFlag }
        self.longFlag = longFlagName.flatMap { $0.asLongFlag }
        self.yamlKey = yamlKey
        self.help = help
    }

    /// Debug/UI helper to refer to the Opt
    var name: String {
        let extendedLongFlag: String?
        if isInvertable, let longFlag = longFlag {
            extendedLongFlag = longFlag.invertableLongFlagSyntax
        } else {
            extendedLongFlag = longFlag
        }

        let flags = [extendedLongFlag,
                     shortFlag,
                     yamlKey.flatMap { "config=\($0)" }]
        return flags.compactMap { $0 }
            .joined(separator: ", ")
    }

    /// A user-sensible string to sort by
    var sortKey: String {
        longFlag?.withoutFlagPrefix ?? yamlKey!
    }

    /// To be overridden
    func set(bool: Bool) { fatalError() }
    func set(string: String) throws { fatalError() }
    func set(path: URL) { fatalError() }
    func set(yaml: Yams.Node) { fatalError() }
    var  type: OptType { fatalError() }
}

/// Intermediate type to add default values and typed option storage.
///
class TypedOpt<OptType>: Opt {
    private var defaultValue: OptType?

    /// Set the default value for the option, before running `OptsParser`.
    @discardableResult
    func def(_ defaultValue: OptType) -> Self {
        self.defaultValue = defaultValue
        return self
    }

    fileprivate(set) var configValue: OptType? {
        willSet(newValue) {
            precondition(newValue != nil)
        }
    }

    /// What is the eventual value of the option?
    var value: OptType? {
        configValue ?? defaultValue
    }

    /// Was the option configured (somehow) by the user?
    /// If this is `false` and `value` is not `nil` then the default value has been used.
    var configured: Bool {
        configValue != nil
    }
}

/// Further intermediate for array options -- replaces optionals with empty arrays
class ArrayOpt<OptElemType>: TypedOpt<[OptElemType]> {
    private var defaultValue = [OptElemType]()

    override var value: [OptElemType] {
        super.value!
    }

    override var repeats: Bool { true }

    /// Add an item to a repeating option
    func add(_ newValue: OptElemType) {
        if (!configured) {
            configValue = [newValue]
        } else {
            configValue?.append(newValue)
        }
    }
}

// MARK: Basic Concrete Option Types

/// Type for clients to describe a boolean option.
/// Boolean options always have a default value: the default default value is `false`.
class BoolOpt: Opt {
    private(set) var value: Bool = false
    private(set) var configured: Bool = false

    @discardableResult
    func def(_ defaultValue: Bool) -> Self {
        value = defaultValue
        return self
    }

    override func set(bool: Bool) {
        value = bool
        configured = true
    }
    override var type: OptType { .bool }
}

/// Special for something like `--version` where we don't want a `--no-version` generated too.
final class CmdOpt: BoolOpt {
    override var isInvertable: Bool { false }
}

/// Type for clients to describe a non-repeating string option,
class StringOpt: TypedOpt<String> {
    override func set(string: String) { configValue = string }
    override var  type: OptType { .string }
}

/// Type for clients to describe a repeating string option.
class StringListOpt: ArrayOpt<String> {
    override func set(string: String) { add(string) }
    override var type: OptType { .string }
}

// MARK: URLs and Path Options

extension URL {
    private func checkExistsTestDir() throws -> Bool {
        let fm = FileManager.default
        var isDir = ObjCBool(false) // !!
        let exists = fm.fileExists(atPath: path, isDirectory: &isDir)
        if !exists {
            throw OptionsError("Path doesn't exist or is inaccessible: \(path)")
        }
        return isDir.boolValue
    }

    /// Helper: does a path exist as a regular file?  Throw if not.
    func checkIsFile() throws {
        if try checkExistsTestDir() {
            throw OptionsError("Path is for a directory not a regular file: \(path)")
        }
    }

    /// Helper: does a path exist as a directory?  Throw if not.
    func checkIsDirectory() throws {
        if try !checkExistsTestDir() {
            throw OptionsError("Path is for a regular file not a directory: \(path)")
        }
    }
}

/// Type for clients to describe a non-repeating pathname option,
final class PathOpt: TypedOpt<URL> {
    override func set(path: URL) { configValue = path }
    override var type: OptType { .path }

    /// Smarter default - interpreted as relative to the current directory
    @discardableResult
    func def(_ defaultValue: String) -> Self {
        def(URL(fileURLWithPath: defaultValue).standardized)
    }

    /// Validation helper, throw unless it's a file
    func checkIsFile() throws {
        try value?.checkIsFile()
    }

    /// Validation helper, throw unless it's a directory
    func checkIsDirectory() throws {
        try value?.checkIsDirectory()
    }
}

/// Type for clients to describe a repeating pathname option.
final class PathListOpt: ArrayOpt<URL> {
    override func set(path: URL) { add(path) }
    override var type: OptType { .path }

    /// Validation helper, throw unless all given are existing files
    func checkAreFiles() throws {
        try value.forEach { try $0.checkIsFile() }
    }
    /// Validation helper, throw unless all given are existing directories
    func checkAreDirectories() throws {
        try value.forEach { try $0.checkIsDirectory() }
    }
}

// MARK: Glob Pattern Options

/// Type for clients to describe a non-repeating glob option,
final class GlobOpt: TypedOpt<Glob.Pattern> {
    override func set(string: String) { configValue = Glob.Pattern(string) }
    override var type: OptType { .glob }
}

/// Type for clients to describe a repeating glob option.
final class GlobListOpt: ArrayOpt<Glob.Pattern> {
    override func set(string: String) { add(Glob.Pattern(string)) }
    override var type: OptType { .glob }
}

/// Type for clients to describe a yaml-only option,
final class YamlOpt: TypedOpt<Yams.Node> {
    override func set(yaml: Yams.Node) { configValue = yaml }
    override var type: OptType { .yaml }
}

// MARK: Enum Options

/// Helpers for enum conversion
extension Opt {
    fileprivate func toEnum<E>(_ e: E.Type, from: String) throws -> E where E: RawRepresentable & CaseIterable, E.RawValue == String {
        guard let eVal = E(rawValue: from) else {
            let caseList = E.allCases.map({$0.rawValue}).joined(separator: ", ")
            throw OptionsError("Bad value '\(from)' for \(name), valid values: \(caseList)")
        }
        return eVal
    }
}

/// Type for clients to describe a repeating closed enum option,
final class EnumListOpt<EnumType>: ArrayOpt<EnumType> where
    EnumType: RawRepresentable, EnumType.RawValue == String,
    EnumType: CaseIterable {
    override func set(string: String) throws {
        add(try toEnum(EnumType.self, from: string))
    }
    override var type: OptType { .string }
    override var repeats: Bool { true }
}

/// Type for clients to describe a non-repeating closed enum option,
final class EnumOpt<EnumType>: TypedOpt<EnumType> where
    EnumType: RawRepresentable, EnumType.RawValue == String,
    EnumType: CaseIterable {
    override func set(string: String) throws {
        configValue = try toEnum(EnumType.self, from: string)
    }
    override var type: OptType { .string }
}

// MARK: OptsParser

/// Apply CLI arguments and a config file to declared client options.
final class OptsParser {
    /// Keep track of which options have already been used to detect repeats.
    /// Rather OTT scaffolding of automatic '--no-foo-bar' longopts....
    final class Tracker {
        let opt: Opt
        var cliSeen: Bool = false
        // Are we an inverted bool (ie. flag present -> set FALSE) flag?
        let invertedBoolOpt: Bool
        // Our inverted bool peer, bidirectional
        weak var partnerTracker: Tracker?

        var partnerCliSeen: Bool {
            partnerTracker.flatMap { $0.cliSeen } ?? false
        }

        init(_ opt: Opt, invertedTracker: Tracker? = nil) {
            self.opt = opt
            if let invertedTracker = invertedTracker {
                self.invertedBoolOpt = true
                self.partnerTracker = invertedTracker
                invertedTracker.partnerTracker = self
            } else {
                self.invertedBoolOpt = false
            }
        }
    }

    /// Hash of all the CLI opts (including - or '--' prefix) to their tracker.
    /// Includes fabricated '--no-foo' opts
    private var flagsDict: Dictionary<String, Tracker> = [:]

    /// Index  for long flags, without their '--' prefix
    private var longFlagsMatcher = PrefixMatcher()

    /// Collection of all the `Opt`s
    private(set) var allOpts = [Opt]()

    /// Add a `Tracker` to the data structures
    private func add(flag: String, tracker: Tracker) {
        precondition(flagsDict[flag] == nil,
                     "Duplicate definition of opt name '\(flag)'")
        flagsDict[flag] = tracker
        if flag.isLongFlag {
            longFlagsMatcher.insert(flag.withoutFlagPrefix)
        }
    }

    /// Try to get a `Tracker` from a flag
    private func matchTracker(flag: String) -> Tracker? {
        if let tracker = flagsDict[flag] {
            return tracker
        }
        guard flag.isLongFlag else {
            return nil
        }
        guard let expandedFlag = longFlagsMatcher.match(flag.withoutFlagPrefix) else {
            return nil
        }
        return flagsDict[expandedFlag.asLongFlag]
    }

    /// Add all an `Opt`'s flags and variants to the trackers
    private func add(opt: Opt) {
        allOpts.append(opt)
        let tracker = Tracker(opt)

        [opt.shortFlag, opt.longFlag, opt.yamlKey].forEach { name in
            name.flatMap { self.add(flag: $0, tracker: tracker) }
        }

        // Auto-generate --no-foo from --foo and vice-versa
        if opt.isInvertable,
            let invertedFlag = opt.longFlag?.invertedLongFlag {
            add(flag: invertedFlag, tracker: Tracker(opt, invertedTracker: tracker))
        }
    }

    /// Add all `Opt`s declared as properties of the object to dictionary
    func addOpts(from: Any) {
        let m = Mirror(reflecting: from)
        m.children.compactMap({ $0.value as? Opt}).forEach {
            self.add(opt: $0)
        }
    }

    /// The base path for interpreting relative paths in options.
    var relativePathBase = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    /// Validate and send string data to a particular option.
    private func apply(stringData: [String], to opt: Opt) throws {
        try stringData.forEach { datum in
            switch opt.type {
            case .glob:
                let url = URL(fileURLWithPath: datum, relativeTo: relativePathBase)
                try opt.set(string: url.standardized.path)
            case .path:
                let url = URL(fileURLWithPath: datum, relativeTo: relativePathBase)
                opt.set(path: url.standardized)
            default:
                try opt.set(string: datum)
            }
        }
    }

    // MARK: CLI

    /// Parse CLI arguments and apply them to options declared via `addOpts()`.
    ///
    /// - throws: if anything is wrong, including: weird text, unrecognized options,
    ///   bad repeats, missing arguments, suspicious-looking globs and paths.  And
    ///   indirectly if enums don't validate.
    func apply(cliOpts: [String]) throws {
        var iter = cliOpts.makeIterator()
        while let next = iter.next() {
            guard next.isFlag else {
                throw OptionsError("Unexpected text '\(next)'")
            }
            guard let tracker = matchTracker(flag: next) else {
                throw OptionsError("Unknown option '\(next)'")
            }
            guard (!tracker.cliSeen && !tracker.partnerCliSeen) || tracker.opt.repeats else {
                throw OptionsError("Unexpected repeated option '\(next)'")
            }
            tracker.cliSeen = true

            if tracker.opt.type == .bool {
                tracker.opt.set(bool: !tracker.invertedBoolOpt)
                continue
            }

            guard let data = iter.next() else {
                throw OptionsError("No argument found for option '\(next)'")
            }

            let allData = tracker.opt.repeats
                // Split on non-escaped commas, then remove any escapes.
                ? data.re_split(#"(?<!\\),"#).map { String($0).re_sub(#"\\,"#, with: ",") }
                : [data]

            try apply(stringData: allData, to: tracker.opt)
        }
    }

    // MARK: YAML

    /// Parse config file and apply contents to options declared via `addOpts()`.
    ///
    /// Assumed to be running *after* `apply(cliOpts:)` and ignores options that
    /// have already been set from the CLI.
    ///
    /// - throws: if the yaml doesn't look exactly as expected or some item validation fails.
    func apply(yaml: String) throws {
        guard let yamlNode = try Yams.compose(yaml: yaml) else {
            throw OptionsError("Could not interpret config file as yaml")
        }

        let rootMapping = try yamlNode.checkMapping(context: "(root)")

        for (key, value) in zip(rootMapping.keys, rootMapping.values) {
            let yamlOptName = try key.checkScalarKey().string
            guard let tracker = flagsDict[yamlOptName] else {
                throw OptionsError("Unrecognized config key '\(yamlOptName)'")
            }
            guard !tracker.cliSeen && !tracker.partnerCliSeen else {
                logWarning("Config key \(yamlOptName) ignored, already set on command-line")
                continue
            }
            // Easy life if opt just wants yaml
            if tracker.opt.type == .yaml {
                tracker.opt.set(yaml: value)
                continue
            }

            // Coerce value into Opt required type
            switch value {
            case .mapping(_):
                throw OptionsError("Unexpected config file shape, found mapping for key '\(yamlOptName)'")

            case .scalar(let scalar):
                if tracker.opt.type == .bool {
                    guard let yamlBool = Bool.construct(from: scalar) else {
                        throw OptionsError("Unexpected text '\(scalar.string)' for config key '\(yamlOptName)', expected boolean")
                    }
                    tracker.opt.set(bool: yamlBool)
                } else {
                    try apply(stringData: [scalar.string], to: tracker.opt)
                }

            case .sequence(let sequence):
                guard sequence.count == 1 || tracker.opt.repeats else {
                    throw OptionsError("Unexpected multiple values '\(try value.asDebugString())' " +
                                       "for config key '\(yamlOptName)', expecting just one")
                }
                let data = try sequence.map { node -> String in
                    try node.checkScalar(context: yamlOptName).string
                }
                try apply(stringData: data, to: tracker.opt)
            }
        }
    }
}

// MARK: Yaml checking helpers

extension Yams.Node {
    func asDebugString() throws -> String {
        let str = try serialize(node: self).replacingOccurrences(of: "\n", with: #"\n"#)
        return str.re_sub(#"\\n$"#, with: "")
    }

    func checkScalarKey() throws -> Yams.Node.Scalar {
        guard let scalar = scalar else {
            let strSelf = try asDebugString()
            throw OptionsError("Unexpected yaml data, mapping key is '\(strSelf)', expected scalar.")
        }
        return scalar
    }

    func checkScalar(context: String) throws -> Yams.Node.Scalar {
        guard let scalar = scalar else {
            let strSelf = try asDebugString()
            throw OptionsError("Unexpected yaml '\(strSelf)' for key '\(context)', expected scalar.")
        }
        return scalar
    }

    func checkMapping(context: String) throws -> Yams.Node.Mapping {
        guard let mapping = mapping else {
            let strSelf = try asDebugString()
            throw OptionsError("Unexpected yaml '\(strSelf)' for key '\(context)', expected mapping.")
        }
        return mapping
    }
}
