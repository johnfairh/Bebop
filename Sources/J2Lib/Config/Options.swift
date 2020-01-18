//
//  Options.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

// Disappointing to write this all but need
// - distributed options
// - config/response file -> CLI overwrite
// - don't touch my stderr/communicate in English/crash the program
//
// All very custom for what we need.

/// Placeholder pending yaml framework
typealias Yaml = Dictionary<String,Any>

/// Base type of an option
enum OptType {
    /// yes/no, implied by option name alone
    case bool
    /// some text, following option name/keyed in the file.  May repeat/be an array.
    case string
    /// special type of text - interpreted relative to cwd/config
    case path
    /// like a path but with wildcards, for matching
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
    let shortFlag: String?
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
        // police flag length/prefix when we decide that
        self.shortFlag = shortFlag
        self.longFlag = longFlag
        self.yamlKey = yamlKey
        self.help = help
    }

    /// Debug/UI helper to refer to the Opt
    var name: String {
        [shortFlag, longFlag, yamlKey].compactMap({$0}).joined()
    }

    /// To be overridden
    func set(bool: Bool) { fatalError() }
    func set(string: String) throws { fatalError() }
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

/// Type for clients to describe a non-repeating pathname option,
final class PathOpt: StringOpt {
    // XXX should be URL
    override var type: OptType { .path }
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

/// Type for clients to describe a non-repeating closed enum option,
final class EnumOpt<EnumType>: TypedOpt<EnumType> where
    EnumType: RawRepresentable, EnumType.RawValue == String,
    EnumType: CaseIterable {
    override func set(string: String) throws {
        guard let eVal = EnumType.init(rawValue: string) else {
            // XXX writeme
            throw Error.options("Bad value '\(string)' for \(name), valid values: hmm")
        }
        configValue = eVal
    }
    override var type: OptType { .string }
}

/// Type for clients to describe a repeating string option.
class StringListOpt: ArrayOpt<String> {
    override func set(string: String) throws { add(string) }
    override var type: OptType { .string }
    override var repeats: Bool { true }
}

/// Type for clients to describe a repeating pathname option.
final class PathListOpt: StringListOpt {
    override var type: OptType { .path }
}

/// Type for clients to describe a repeating glob option.
final class GlobListOpt: StringListOpt {
    override var type: OptType { .glob }
}

/// Type for clients to describe a repeating closed enum option,
final class EnumListOpt<EnumType>: TypedOpt<[EnumType]> where
    EnumType: RawRepresentable, EnumType.RawValue == String,
    EnumType: CaseIterable {
    override func set(string: String) throws {
        guard let eVal = EnumType.init(rawValue: string) else {
            // XXX writeme
            throw Error.options("Bad value '\(string)' for \(name), valid values: hmm")
        }
        // validate
        add(eVal)
    }
    override var type: OptType { .string }
    override var repeats: Bool { true }
}

// MARK: OptsParser

/// Apply CLI arguments and a config file to declared client options.
final class OptsParser {
    /// Keep track of which options have already been used to detect repeats.
    final class OptTracker {
        let opt: Opt
        var cliSeen: Bool = false
        init(_ opt: Opt) {
            self.opt = opt
        }
    }
    var optsDict: Dictionary<String, OptTracker> = [:]

    private func add(opt: Opt) {
        let reqs = OptTracker(opt)
        // auto --[no-]-long
        [opt.shortFlag, opt.longFlag, opt.yamlKey].forEach { name in
            // dup check
            name.flatMap { self.optsDict[$0] = reqs }
        }
    }

    /// Add all `Opt`s declared as properties of the object to dictionary
    func addOpts(from: Any) {
        let m = Mirror(reflecting: from)
        m.children.compactMap({ $0.value as? Opt}).forEach {
            self.add(opt: $0)
        }
    }

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
            // XXX prefix-match
            guard let tracker = optsDict[next] else {
                throw Error.options("Unknown option \(next)")
            }
            // XXX if bool and long consider invert, raise if both set
            guard !tracker.cliSeen || tracker.opt.repeats else {
                throw Error.options("Unexpected repeated option \(next)")
            }
            tracker.cliSeen = true
            if tracker.opt.type == .bool {
                tracker.opt.set(bool: true)
                continue
            }
            guard let data = iter.next() else {
                throw Error.options("No argument found for option \(next)")
            }
            guard !tracker.opt.repeats || !data.contains(",") else {
                throw Error.notImplemented("OptArg Arrayification")
            }
            switch tracker.opt.type {
            case .glob: throw Error.notImplemented("Glob validation")
            case .path: throw Error.notImplemented("Path validation")
            default: break;
            }
            try tracker.opt.set(string: data)
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
