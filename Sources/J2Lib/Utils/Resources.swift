//
//  Resources.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

//
// This stuff is about accessing the resources associated with the program.
// These resources are made up of static files used to generate the docs,
// and static files used during runtime -- primarily localized strings files.
//
// This code is a huge mess because SwiftPM can't do bundles and resources,
// and the open-source Foundation/CF that Linux etc. use has crucial gaps
// around localization and bundles.
//
// The good news is this will >95% go away in a couple of years when Swift PM
// and CF do have these features and the bugs have been ironed out.
//
// Quick summary of the things being worked around:
// 1) Raw executables don't have a proper `Bundle.main` -- that bundle has a
//    path matching the executable, but no other useful properties.
//
// 1a) FHS bundles might work in some sense but don't work in the sense of
//     providing a proper `Bundle.main` from a ${prefix}/bin/foo / ${prefix}/share/foo.resources
//     set.
//
// 1b) So in the raw executable case (SPM) we have to manually hunt down the
//     resource bundle.
//
// 2) CF's preferred localization algorithm is: "get the bundle's available languages,
//    intersect those with the main bundle's languages, then smart-match against the
//    user's preferred languages".  In reality:
//
// 2a) Raw executables don't have a real main bundle, their languages come out as [],
//     and knock out all the available languages.
//
// 2b) The smart-match algorithm, even the version that promises to be
//     a pure function of its input lists, is broken/missing in !Darwin.
//
// 2c) CF disdains $LANG & co. so there are in fact no preferred languages on
//     !Darwin.  It disdains $LANG on Darwin too but the userdefaults etc. all works.
//
// 2d) There is no `Bundle` API to get a string from a specific locale, you have to
//     use the adorable preferred localization algorithm.
//
// 2e) This all means the hundreds of lines of 1990s-style CF code amount to 'return "en"'.
//
// 2f) And so we have to manually pick the localization to use, on !Darwin this means
//     parsing $LANG, and create a sub-bundle wrapping the .lproj that we want to use
//     in order to access the strings API.
//
// 3) Oh and `Bundle(for:)` just crashes on !Darwin.  And can't be used with a struct!
//
// It's been a day.

import Foundation

extension String {
    /// Helper to grab a localized string and do substitutions %1 .... %n
    static func localized(_ key: String, _ subs: Any...) -> String {
        var result = Resources.shared.string(key)
        subs.enumerated().forEach { idx, sub in
            result = result.re_sub("%\(idx+1)", with: String(describing: sub))
        }
        return result
    }
}

public final class Resources {
    /// The bundle for accessing non-localized resources
    let bundle: Bundle
    /// The bundle for accessing localized resources
    let localizationBundle: Bundle

    private init(bundle: Bundle, localizationBundle: Bundle) {
        self.bundle = bundle
        self.localizationBundle = localizationBundle
    }

    /// Get localized help text
    func helpText(optionName: String) -> String {
        return localizationBundle.localizedString(forKey: optionName,
                                                  value: "(No help provided)",
                                                  table: "Help")
    }

    /// Read a localized string
    func string(_ key: String, value: String? = nil) -> String {
        return localizationBundle.localizedString(forKey: key, value: value ?? "This is not text", table: nil)
    }

    private(set) static var shared: Resources!

    // MARK: Main bundle location

    /// We initialize the resource bundles before we process options (so that we can report localized
    /// error messages about problems with the options) which means that we keep debug messages
    /// recording our tortuous initialization for later playback.
    ///
    private static var debugLog = [String]()
    
    private static func log(_ msg: String) {
        debugLog.append(msg)
    }

    public static func logInitializationProgress() {
        debugLog.forEach { logDebug($0) }
    }

    /// Hook for xctest and unpredictable embeddings - manually specify where the resource bundle is
    public static let BUNDLE_ENV_VAR = "J2_RESOURCES_PATH"

    /// Initialise the resource and localization bundles.
    /// Works or halts the process.
    public static func initialize() {
        guard shared == nil else {
            return
        }

        let mainBundle: Bundle
        if let injectedMainBundlePath = ProcessInfo.processInfo.environment[BUNDLE_ENV_VAR] {
            guard let bundle = Bundle(path: injectedMainBundlePath) else {
                preconditionFailure("Can't load resources bundle at \(BUNDLE_ENV_VAR)=\(injectedMainBundlePath)")
            }
            mainBundle = bundle
        } else {
            #if SWIFT_PACKAGE
            mainBundle = spmFindMainBundle()
            #else
            mainBundle = xcodeFindMainBundle()
            #endif
        }

        log("Resource bundle path: \(mainBundle.bundlePath)")

        let localizationBundle = findLocalizationBundle(in: mainBundle)

        log("Localization bundle path: \(localizationBundle.bundlePath)")

        shared = Resources(bundle: mainBundle, localizationBundle: localizationBundle)
    }

    /// In Xcode world, we have a framework bundle and the resource bundle is a "plugin" sub-bundle of the
    /// J2Lib framework bundle.  This is (sort of) how the APIs want this to work.
    static func xcodeFindMainBundle() -> Bundle {
        let frameworkBundle = Bundle(for: Resources.self)

        guard let pluginsURL = frameworkBundle.builtInPlugInsURL,
            case let resourceBundleURL = pluginsURL.appendingPathComponent("J2Resources.bundle"),
            let resourceBundle = Bundle(url: resourceBundleURL) else {
            preconditionFailure("Packaging looks broken, can't find 'Plugins/J2Resources.bundle' " +
                "inside framework bundle \(frameworkBundle.bundlePath)")
        }

        return resourceBundle
    }

    /// In SPM world we are using an FHS bundle but have to guess where it is from the
    /// executable.  Obsoleted tech note QA1436 suggests the main bundle (which is mostly useless)
    /// is the best way of getting there.
    static func spmFindMainBundle() -> Bundle {
        let binaryDirectory = URL(fileURLWithPath: Bundle.main.bundlePath)
        let bundleFileName = "j2.resources"

        // First try in same directory
        let adjacentBundle = binaryDirectory.appendingPathComponent(bundleFileName)
        if FileManager.default.fileExists(atPath: adjacentBundle.path) {
            guard let resourceBundle = Bundle(url: adjacentBundle) else {
                preconditionFailure("Installation looks broken, can't open resource bundle at " +
                    "\(adjacentBundle.path)")
            }
            log("SPM main bundle: using adjacent bundle")
            return resourceBundle
        }

        // Now try in a prefix tree, hopping from `bin` to `share`.
        guard binaryDirectory.lastPathComponent == "bin" else {
            preconditionFailure("Installation looks broken, not installed in a 'bin' directory " +
                "or with 'j2.resources' in the same directory as the executable, " +
                "\(binaryDirectory.path)")
        }
        let fhsBundle = binaryDirectory.deletingLastPathComponent()
            .appendingPathComponent("share")
            .appendingPathComponent(bundleFileName)
        guard let resourceBundle = Bundle(url: fhsBundle) else {
            preconditionFailure("Installation looks broken, executable in 'bin' directory " +
                "\(binaryDirectory.path) but can't find 'j2.resources' bundle at \(fhsBundle.path)")
        }
        log("SPM main bundle: using FHS-style bundle in `share` tree")
        return resourceBundle
    }

    // MARK: Localization selection

    /// Pick the localization we're going to use (for our own messages and logging, not of the generated docs.
    ///
    /// The automatic stuff doesn't work if there is no main bundle (CLI tool) or on non-Darwin.
    /// So this is a horrible mess.
    ///
    static func findLocalizationBundle(in bundle: Bundle) -> Bundle {
        let LPROJ = "lproj"

        guard let lprojs = bundle.urls(forResourcesWithExtension: LPROJ, subdirectory: nil) else {
            preconditionFailure("Installation looks corrupt, can't find any 'lproj' subdirectories " +
                "inside main bundle \(bundle.bundlePath)")
        }

        #if os(Linux)
        let supported = lprojs.map { String($0.lastPathComponent!.dropLast(LPROJ.count + 1)) }
        #else
        let supported = lprojs.map { String($0.lastPathComponent.dropLast(LPROJ.count + 1)) }
        #endif // wtf was that

        log("Localization bundle: Supported: \(supported)")

        func preferredLanguage() -> String? {
            let localePreferred = Locale.preferredLanguages
            if !localePreferred.isEmpty {
                log("Localization bundle: Locale has preferences: \(localePreferred)")
                guard let selected = Bundle.preferredLocalizations(from: supported,
                                                                   forPreferences: localePreferred).first,
                    supported.contains(selected) else {
                    // This means Bundle is ordering off-menu again
                    log("Localization bundle: Bundle.preferredLocalizations() is confused")
                    return nil
                }
                return selected
            }

            // Some furrin platform that CF doesn't understand.
            // Not only is Locale broken, Bundle.preferredLocalizations(from:forPrefs:) is too.
            let (choice, msg) = chooseLanguageFromEnvironment(choices: supported)
            log(msg)
            return choice
        }

        // As appears traditional: fall back to en...
        let chosen = preferredLanguage() ?? "en"
        guard let resourceURL = bundle.resourceURL,
            case let localizationURL = resourceURL.appendingPathComponent("\(chosen).\(LPROJ)"),
            let locBundle = Bundle(url: localizationURL) else {
            preconditionFailure("Installation looks corrupt - can no longer find .lproj directory " +
                "\(chosen) in \(bundle.bundlePath) that we thought was there earlier (\(lprojs))")
        }
        return locBundle
    }

    /// Parse environment variables to figure out the user's preferred language.
    /// Lots of space for improvement here but hoping CF gets fixed first.
    /// Factored out for unit test.
    static func chooseLanguageFromEnvironment(choices: [String]) -> (result: String?, log: String) {
        let langVar = ProcessInfo.processInfo.environment["LANG"]
        let log = "Localization bundle: using LANG \(langVar ?? "(nil)")"

        guard let lv = langVar, let match = lv.re_match(#"^(.*)\.?"#) else {
            return (nil, log)
        }

        let languageCountry = match[1]
        let language = String(languageCountry.prefix(2))

        for match in [languageCountry, language] {
            if choices.contains(match) {
                return (match, log)
            }
        }

        return (nil, log)
    }
}
