//
//  Options.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

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

/// Placeholder pending yaml framework
typealias Yaml = Dictionary<String,Any>

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
    /// Single-character flag.  Does not include leading hyphen.
    let shortFlag: String?
    /// Multiple-character flag.  Does not include leading hyphens.
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
    var  repeats: Bool { false }

    /// At least one of `longFlag` and `yamlKey` must be set.
    init(s shortFlag: String? = nil, l longFlag: String? = nil, y yamlKey: String? = nil, help: String) {
        precondition(longFlag != nil || yamlKey != nil, "Opt must have a long name somewhere")
        shortFlag.flatMap { precondition(!$0.hasPrefix("-"), "Option names don't include the hyphen") }
        longFlag.flatMap { precondition(!$0.hasPrefix("--"), "Option names don't include the hyphen") }
        self.shortFlag = shortFlag.flatMap { "-\($0)" }
        self.longFlag = longFlag.flatMap { "--\($0)" }
        self.yamlKey = yamlKey
        self.help = help
    }

    /// Debug/UI helper to refer to the Opt
    var name: String {
        [shortFlag, longFlag, yamlKey].compactMap({$0}).joined()
    }

    var invertedLongFlag: String? {
        guard let longFlag = longFlag else {
            return nil
        }
        if longFlag.hasPrefix("--no-") {
            return longFlag.re_sub("^--no-", with: "--")
        }
        return longFlag.re_sub("^--", with: "--no-")
    }

    /// To be overridden
    func set(bool: Bool) { fatalError() }
    func set(string: String) throws { fatalError() }
    func set(path: URL) throws { fatalError() }
    func set(yaml: Yaml) throws { fatalError() }
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

    /// Add an item to a repeating option
    func add<Element>(_ newValue: Element) where OptType == Array<Element> {
        if (!configured) {
            configValue = [newValue]
        } else {
            configValue?.append(newValue)
        }
    }
}

/// Further intermediate for array options -- replaces optionals with empty arrays
class ArrayOpt<OptElemType>: TypedOpt<[OptElemType]> {
    private var defaultValue = [OptElemType]()

    override var value: [OptElemType] {
        super.value!
    }

    override var repeats: Bool { true }
}

// MARK: Concrete Opts

/// Type for clients to describe a boolean option.
/// Boolean options always have a default value: the default default value is `false`.
final class BoolOpt: Opt {
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

/// Type for clients to describe a non-repeating string option,
class StringOpt: TypedOpt<String> {
    override func set(string: String) { configValue = string }
    override var  type: OptType { .string }
}

extension URL {
    private func checkExistsTestDir() throws -> Bool {
        let fm = FileManager.default
        var isDir = ObjCBool(false) // !!
        let exists = fm.fileExists(atPath: path, isDirectory: &isDir)
        if !exists {
            throw Error.options("Path doesn't exist or is inaccessible: \(path)")
        }
        return isDir.boolValue
    }

    /// Helper: does a path exist as a regular file?  Throw if not.
    func checkIsFile() throws {
        if try checkExistsTestDir() {
            throw Error.options("Path is for a directory not a regular file: \(path)")
        }
    }

    /// Helper: does a path exist as a directory?  Throw if not.
    func checkIsDirectory() throws {
        if !(try checkExistsTestDir()) {
            throw Error.options("Path is for a regular file not a directory: \(path)")
        }
    }
}

/// Type for clients to describe a non-repeating pathname option,
final class PathOpt: TypedOpt<URL> {
    override func set(path: URL) { configValue = path }
    override var type: OptType { .path }

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
    override func set(path: URL) throws { add(path) }
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

/// Type for clients to describe a non-repeating glob option,
final class GlobOpt: StringOpt {
    // XXX should be insane glob type
    override var type: OptType { .glob }
}

/// Type for clients to describe a yaml-only option,
final class YamlOpt: TypedOpt<Yaml> {
    override func set(yaml: Yaml) { configValue = yaml }
    override var type: OptType { .yaml }
}

/// Type for clients to describe a repeating string option.
class StringListOpt: ArrayOpt<String> {
    override func set(string: String) throws { add(string) }
    override var type: OptType { .string }
}


/// Type for clients to describe a repeating glob option.
final class GlobListOpt: StringListOpt {
    override var type: OptType { .glob }
}

/// Helper sfor enum conversion
extension Opt {
    fileprivate func toEnum<E>(_ e: E.Type, from: String) throws -> E where E: RawRepresentable & CaseIterable, E.RawValue == String {
        guard let eVal = E(rawValue: from) else {
            throw Error.options("Bad value '\(from)' for \(name), valid values: \(E.caseList)")
        }
        return eVal
    }
}

extension CaseIterable where Self: RawRepresentable, RawValue == String {
    static var caseList: String {
        allCases.map({$0.rawValue}).joined(separator: ", ")
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
    final class OptTracker {
        let opt: Opt
        var cliSeen: Bool = false
        // Are we an inverted bool (ie. flag present -> set FALSE) flag?
        let invertedBoolOpt: Bool
        // Our inverted bool peer, bidirectional
        weak var partnerOptTracker: OptTracker?

        init(_ opt: Opt, invertedOptTracker: OptTracker? = nil) {
            self.opt = opt
            if let invertedOptTracker = invertedOptTracker {
                self.invertedBoolOpt = true
                self.partnerOptTracker = invertedOptTracker
                invertedOptTracker.partnerOptTracker = self
            } else {
                self.invertedBoolOpt = false
            }
        }
    }

    // Hash of all the CLI opts (including - or '--' prefix) to their tracker.
    // Includes fabricated '--no-foo' opts
    var optsDict: Dictionary<String, OptTracker> = [:]

    // Tracker for long opts, without their '--' prefix
    var longOptsMatcher = PrefixMatcher()

    private func add(opt: Opt) {
        let tracker = OptTracker(opt)

        [opt.shortFlag, opt.longFlag, opt.yamlKey].forEach { name in
            name.flatMap {
                precondition(self.optsDict[$0] == nil,
                    "Duplicate definition of opt name '\($0)'")
                self.optsDict[$0] = tracker
            }
        }

        // Auto-generate --no-foo from --foo and vice-versa
        if opt.type == .bool,
            let invertedName = opt.invertedLongFlag {
            precondition(optsDict[invertedName] == nil,
                "Duplicate (implicit?) definition of opt name '\(invertedName)'")
            optsDict[invertedName] = OptTracker(opt, invertedOptTracker: tracker)
        }

        // Store away the long opt name for partial matching
        if let longOpt = opt.longFlag {
            precondition(longOpt.hasPrefix("--"))
            longOptsMatcher.insert(String(longOpt.dropFirst(2)))
        }
    }

    /// Add all `Opt`s declared as properties of the object to dictionary
    func addOpts(from: Any) {
        let m = Mirror(reflecting: from)
        m.children.compactMap({ $0.value as? Opt}).forEach {
            self.add(opt: $0)
        }
    }

    private func match(option: String) -> OptTracker? {
        if let tracker = optsDict[option] {
            return tracker
        }
        guard option.hasPrefix("--") else {
            return nil
        }
        guard let expandedOpt = longOptsMatcher.match(String(option.dropFirst(2))) else {
            return nil
        }
        return match(option: "--\(expandedOpt)")
    }

    /// The base path for interpreting relative paths in options.
    var relativePathBase = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    /// Parse CLI arguments and apply them to options declared via `addOpts()`.
    ///
    /// - throws: if anything is wrong, including: weird text, unrecognized options,
    ///   bad repeats, missing arguments, suspicious-looking globs and paths.  And
    ///   indirectly if enums don't validate.
    func apply(cliOpts: [String]) throws {
        var iter = cliOpts.makeIterator()
        while let next = iter.next() {
            guard next.hasPrefix("-") else {
                throw Error.options("Unexpected text '\(next)'")
            }
            guard let tracker = match(option: next) else {
                throw Error.options("Unknown option \(next)")
            }
            guard !tracker.cliSeen || tracker.opt.repeats else {
                throw Error.options("Unexpected repeated option \(next)")
            }
            tracker.cliSeen = true
            tracker.partnerOptTracker?.cliSeen = true
            if tracker.opt.type == .bool {
                tracker.opt.set(bool: !tracker.invertedBoolOpt)
                continue
            }

            guard let data = iter.next() else {
                throw Error.options("No argument found for option \(next)")
            }
            let allData = tracker.opt.repeats
                // Split on non-escaped commas, then remove any escapes.
                ? data.re_split(#"(?<!\\),"#).map { String($0).re_sub(#"\\,"#, with: ",") }
                : [data]

            try allData.forEach { datum in
                switch tracker.opt.type {
                case .glob: throw Error.notImplemented("Glob validation")
                case .path:
                    let url = URL(fileURLWithPath: datum, relativeTo: relativePathBase)
                    try tracker.opt.set(path: url.standardized)
                default:
                    try tracker.opt.set(string: datum)
                }
            }
        }
    }

    func apply(yaml: Yaml) throws {
        // each root key
        //  lookup as yaml or raise
        //  warning and next if seen on cli
        //  if yaml then set and next
        //  allow 1-elem array for !repeats else raise
        //  no grandchildren else raise
        //  if bool then set and next
        //  if path or glob then validate each
        //  set each and next
    }
}
