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
// - localized string options with per-language values
// - alias options
// - cascade

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

    var asYamlKey: String {
        asSwiftEnumCase
    }

    var asCliEnumCase: String {
        replacingOccurrences(of: "_", with: "-")
    }

    var asSwiftEnumCase: String {
        replacingOccurrences(of: "-", with: "_")
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
    /// a localized string, simple on the CLI or a map in the config file.
    case locstring
    /// an arbitrary yaml structure, not on the CLI
    case yaml
}

/// Yaml key policy
enum OptYaml {
    /// No yaml key
    case none
    /// Generate from the long opt
    case auto
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

    /// CLI options that may have yaml as well.
    /// Don't include "-" at the start of flag names.
    init(s shortFlagName: String? = nil, l longFlagName: String, yaml: OptYaml = .auto) {
        shortFlagName.flatMap { precondition(!$0.isFlag, "Option names don't include the hyphen") }
        precondition(!longFlagName.isFlag, "Option names don't include the hyphen")
        self.shortFlag = shortFlagName.flatMap { $0.asShortFlag }
        self.longFlag = longFlagName.asLongFlag
        switch yaml {
        case .none: yamlKey = nil
        case .auto: yamlKey = longFlagName.asYamlKey
        }
    }

    /// YAML-only options
    init(y yaml: String) {
        shortFlag = nil
        longFlag = nil
        yamlKey = yaml
    }

    /// Debug/UI helper to refer to the Opt
    func name(usage: Bool) -> String {
        var output = ""
        if let longFlag = longFlag {
            if isInvertable {
                output = longFlag.invertableLongFlagSyntax
            } else {
                output = longFlag
            }
            if let shortFlag = shortFlag {
                output += "|\(shortFlag)"
            }
            if type != .bool && usage {
                output += " \(helpParam)"
            }
        } else {
            output = yamlKey!
            if usage {
                output += " (config key only)" // XXX localize
            }
        }
        return output
    }

    /// A user-sensible string to sort by
    var sortKey: String {
        longFlag?.withoutFlagPrefix ?? yamlKey!
    }

    /// Help text stored in strings file, keyed by the `sortKey`
    var help: String {
        Resources.shared.helpText(optionName: sortKey)
    }

    /// To be overridden
    func set(bool: Bool) { fatalError() }
    func set(string: String) throws { fatalError() }
    func set(string: String, path: URL) { fatalError() }
    func set(locstring: Localized<String>) { fatalError() }
    func set(yaml: Yams.Node) { fatalError() }
    var  type: OptType { fatalError() }
    var  helpParam: String { "" }
}

/// Begrudging support for option aliases.  These don't appear in help.
struct AliasOpt {
    let realOpt: Opt
    let aliases: [String]

    init(realOpt: Opt, s shortFlagName: String? = nil, l longFlagName: String, yaml: OptYaml = .auto) {
        self.realOpt = realOpt
        var aliases = [String]()
        if let short = shortFlagName {
            precondition(!short.isFlag, "Option names don't include the hyphen")
            aliases.append(short.asShortFlag)
        }
        precondition(!longFlagName.isFlag, "Option names don't include the hyphen")
        aliases.append(longFlagName.asLongFlag)
        if yaml == .auto {
            aliases.append(longFlagName.asYamlKey)
        }
        self.aliases = aliases
    }
}

protocol OptHelpers: class {
    associatedtype OptHelperType
    var defaultValue: OptHelperType? { get set }
    var theHelpParam: String? { get set }
}

extension OptHelpers {
    /// Set the default value for the option, before running `OptsParser`.
    @discardableResult
    func def(_ defaultValue: OptHelperType) -> Self {
        self.defaultValue = defaultValue
        return self
    }

    /// Set the help param value for the option, before running `OptsParser`.
    @discardableResult
    func help(_ helpParam: String) -> Self {
        self.theHelpParam = helpParam
        return self
    }
}

protocol OptCascadable {
    /// Did the "user" provide a value for this option?
    var configured: Bool { get }

    /// Set the value from some other option of the right type, provided it is configured and we are not.
    func cascade(from: Self)
}

extension OptCascadable {
    func shouldCascade(from: Self) -> Bool {
        !configured && from.configured
    }
}

/// Intermediate type to add default values and typed option storage.
class TypedOpt<OptType>: Opt, OptHelpers, OptCascadable, CustomStringConvertible {
    var defaultValue: OptType?
    var theHelpParam: String?

    override var helpParam: String {
        return theHelpParam ?? ""
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

    /// Set the value from some other option of the right type, provided it is configured and we are not.
    func cascade(from: TypedOpt<OptType>) {
        if shouldCascade(from: from) {
            configValue = from.configValue
        }
    }

    /// Debug
    var description: String {
        var str = "Opt \(sortKey)"
        if let configValue = configValue {
            str += "=\(configValue)"
        } else if let defValue = defaultValue {
            str += "=(default)\(defValue)"
        } else {
            str += "(unset)"
        }
        return str
    }
}

/// Further intermediate for array options -- replaces optionals with empty arrays
class ArrayOpt<OptElemType>: TypedOpt<[OptElemType]> {
    override var value: [OptElemType] {
        super.value ?? []
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
class BoolOpt: Opt, OptCascadable, CustomStringConvertible {
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

    /// Set the value from some other option of the right type, provided it is configured and we are not.
    func cascade(from: BoolOpt) {
        if shouldCascade(from: from) {
            set(bool: from.value)
        }
    }

    /// Debug
    var description: String {
        var str = "Opt \(sortKey)"
        if configured {
            str += "=\(value)"
        } else {
            str += "=(default)\(value)"
        }
        return str
    }
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
            throw OptionsError(.localized(.errPathNotExist, path))
        }
        return isDir.boolValue
    }

    /// Helper: does a path exist as a regular file?  Throw if not.
    func checkIsFile() throws {
        if try checkExistsTestDir() {
            throw OptionsError(.localized(.errPathNotFile, path))
        }
    }

    /// Helper: does a path exist as a directory?  Throw if not.
    func checkIsDirectory() throws {
        if try !checkExistsTestDir() {
            throw OptionsError(.localized(.errPathNotDir, path))
        }
    }
}

/// Type for clients to describe a non-repeating pathname option,
/// Because 'theme' we store what they typed as well as the expanded path....
final class PathOpt: TypedOpt<URL> {
    var configStringValue: String?
    override func set(string: String, path: URL) {
        configStringValue = string
        configValue = path
    }
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
    override func set(string: String, path: URL) { add(path) }
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

extension String {
    /// Validation for user-supplied regexps
    func re_check() throws {
        do {
            let _ = try NSRegularExpression(pattern: self)
        } catch {
            throw OptionsError(.localized(.errCfgRegexp, self, error))
        }
    }
}

// MARK: Enum Options

/// Helpers for enum conversion

private func caseList<E>(_ enum: E.Type, separator: String) -> String
    where E: RawRepresentable & CaseIterable, E.RawValue == String {
    E.allCases.map({$0.rawValue.asCliEnumCase}).joined(separator: separator)
}

extension Opt {
    fileprivate func toEnum<E>(_ e: E.Type, from: String) throws -> E
        where E: RawRepresentable & CaseIterable, E.RawValue == String {
        guard let eVal = E(rawValue: from.asSwiftEnumCase) else {
            throw OptionsError(.localized(.errEnumValue,
                from, name(usage: false), caseList(E.self, separator: ", ")))
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
    override var helpParam: String {
        caseList(EnumType.self, separator: " | ") + ", ..."
    }
}

/// Type for clients to describe a non-repeating closed enum option,
final class EnumOpt<EnumType>: TypedOpt<EnumType> where
    EnumType: RawRepresentable, EnumType.RawValue == String,
    EnumType: CaseIterable {
    override func set(string: String) throws {
        configValue = try toEnum(EnumType.self, from: string)
    }
    override var type: OptType { .string }
    override var helpParam: String {
        caseList(EnumType.self, separator: " | ")
    }
}

// MARK: Localized Stringsets

final class LocStringOpt: Opt, OptHelpers, OptCascadable, CustomStringConvertible {
    var defaultValue: String?
    private(set) var flatConfig: String?
    private(set) var dictConfig: Localized<String>?

    /// Client responsible for not evaluating this until the actual desired
    /// localizations have been configured, otherwise wackiness will ensue.
    lazy var value: Localized<String>? = {
        if var dictConfig = dictConfig {
            let missing = dictConfig.expandLanguages()
            logWarning(.localized(.wrnCfgLanguageMissing, name(usage: false), missing))
            return dictConfig
        }
        return (flatConfig ?? defaultValue).flatMap {
            Localized<String>(unlocalized: $0)
        }
    }()

    var theHelpParam: String?
    
    override var helpParam: String {
        return theHelpParam ?? ""
    }

    var configured: Bool {
        flatConfig != nil || dictConfig != nil
    }

    override func set(string: String) {
        flatConfig = string
    }

    override func set(locstring: Localized<String>) {
        dictConfig = locstring
    }

    override var type: OptType { .locstring }

    /// Set the value from some other option of the right type, provided it is configured and we are not.
    func cascade(from: LocStringOpt) {
        if shouldCascade(from: from) {
            flatConfig = from.flatConfig
            dictConfig = from.dictConfig
        }
    }

    /// Debug
    var description: String {
        var str = "Opt \(sortKey)"
        if let flatConfig = flatConfig {
            str += "=\(flatConfig)"
        } else if let dictConfig = dictConfig {
            str += "=\(dictConfig)"
        } else if let defValue = defaultValue {
            str += "=(default)\(defValue)"
        } else {
            str += "(unset)"
        }
        return str
    }
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

    /// The base path for interpreting relative paths in options.
    var relativePathBase: URL

    /// Create a new parser, seeding the base for relative paths - default to the current directory.
    init(relativePathBase: URL? = nil) {
        self.relativePathBase = relativePathBase ?? FileManager.default.currentDirectory
    }

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

    /// Add some aliases for an existing opt
    private func addAlias(opt: AliasOpt) {
        guard let realOptLongFlag = opt.realOpt.longFlag,
            let tracker = matchTracker(flag: realOptLongFlag) else {
            preconditionFailure("Can't resolve AliasOpt \(opt)")
        }
        opt.aliases.forEach { self.add(flag: $0, tracker: tracker) }
    }

    /// Add all `Opt`s declared as properties of the object to dictionary
    func addOpts(from: Any) {
        let m = Mirror(reflecting: from)
        m.children.compactMap({ $0.value as? Opt}).forEach {
            self.add(opt: $0)
        }
        m.children.compactMap({ $0.value as? AliasOpt}).forEach {
            self.addAlias(opt: $0)
        }
    }

    /// Validate and send string data to a particular option.
    private func apply(stringData: [String], to opt: Opt) throws {
        try stringData.forEach { datum in
            switch opt.type {
            case .glob:
                let url = URL(fileURLWithPath: datum, relativeTo: relativePathBase)
                try opt.set(string: url.standardized.path)
            case .path:
                let url = URL(fileURLWithPath: datum, relativeTo: relativePathBase)
                opt.set(string: datum, path: url.standardized)
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
        while var next = iter.next() {
            guard next.isFlag else {
                throw OptionsError(.localized(.errCliUnexpected, next))
            }

            var nextArg: String? = nil

            if next.isLongFlag && next.contains("=") {
                let words = next.split(separator: "=")
                next = String(words.first!)
                nextArg = words[1...].joined(separator: "=")
            }

            guard let tracker = matchTracker(flag: next) else {
                throw OptionsError(.localized(.errCliUnknownOption, next))
            }
            if let nextArg = nextArg, tracker.opt.type == .bool {
                throw OptionsError(.localized(.errCliUnknownOption, "\(next)=\(nextArg)"))
            }
            guard (!tracker.cliSeen && !tracker.partnerCliSeen) || tracker.opt.repeats else {
                throw OptionsError(.localized(.errCliRepeated, next))
            }
            tracker.cliSeen = true

            if tracker.opt.type == .bool {
                tracker.opt.set(bool: !tracker.invertedBoolOpt)
                continue
            }

            guard let data = nextArg ?? iter.next() else {
                throw OptionsError(.localized(.errCliMissingArg, next))
            }

            let allData = tracker.opt.repeats
                // Split on non-escaped commas, then remove any escapes.
                ? data.re_split(#"(?<!\\),"#).map { $0.re_sub(#"\\,"#, with: ",") }
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
            throw OptionsError(.localized(.errCfgNotYaml))
        }

        let rootMapping = try yamlNode.checkMapping(context: "(root)")
        return try apply(mapping: rootMapping)
    }

    /// Version of `apply(yaml:)` for an existing Yams `Node.Mapping`.
    func apply(mapping rootMapping: Node.Mapping) throws {
        for (key, value) in zip(rootMapping.keys, rootMapping.values) {
            let yamlOptName = try key.checkScalarKey().string
            guard let tracker = flagsDict[yamlOptName] else {
                throw OptionsError(.localized(.errCfgBadKey, yamlOptName))
            }
            guard !tracker.cliSeen && !tracker.partnerCliSeen else {
                logWarning(.localized(.wrnCfgIgnored, yamlOptName))
                continue
            }
            // Easy life if opt just wants yaml
            if tracker.opt.type == .yaml {
                tracker.opt.set(yaml: value)
                continue
            }

            // Coerce value into Opt required type
            switch value {
            case .mapping(let mapping):
                guard tracker.opt.type == .locstring else {
                    throw OptionsError(.localized(.errCfgBadMapping, yamlOptName))
                }
                var locStr = Localized<String>()
                for (k, v) in zip(mapping.keys, mapping.values) {
                    let lang = try k.checkScalarKey().string
                    let str = try v.checkScalar(context: lang).string
                    locStr[lang] = str
                }
                tracker.opt.set(locstring: locStr)

            case .scalar(let scalar):
                if tracker.opt.type == .bool {
                    guard let yamlBool = Bool.construct(from: scalar) else {
                        throw OptionsError(.localized(.errCfgTextNotBool, scalar.string, yamlOptName))
                    }
                    tracker.opt.set(bool: yamlBool)
                } else {
                    try apply(stringData: [scalar.string], to: tracker.opt)
                }

            case .sequence(let sequence):
                guard sequence.count == 1 || tracker.opt.repeats else {
                    throw OptionsError(.localized(.errCfgMultiSeq,
                                                  try value.asDebugString(), yamlOptName))
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
            throw OptionsError(.localized(.errCfgNonScalarKey, strSelf))
        }
        return scalar
    }

    func checkScalar(context: String) throws -> Yams.Node.Scalar {
        guard let scalar = scalar else {
            let strSelf = try asDebugString()
            throw OptionsError(.localized(.errCfgNotScalar, strSelf, context))
        }
        return scalar
    }

    func checkMapping(context: String) throws -> Yams.Node.Mapping {
        guard let mapping = mapping else {
            let strSelf = try asDebugString()
            throw OptionsError(.localized(.errCfgNotMapping, strSelf, context))
        }
        return mapping
    }

    func checkSequence(context: String) throws -> Yams.Node.Sequence {
        guard let sequence = sequence else {
            let strSelf = try asDebugString()
            throw OptionsError(.localized(.errCfgNotSequence, strSelf, context))
        }
        return sequence
    }
}
