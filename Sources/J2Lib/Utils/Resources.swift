//
//  Resources.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

public final class Resources {

    let bundle: Bundle
    let localizationBundle: Bundle

    init(bundle: Bundle, localizationBundle: Bundle) {
        self.bundle = bundle
        self.localizationBundle = localizationBundle
    }

    func string(_ key: String, value: String? = nil) -> String {
        return localizationBundle.localizedString(forKey: key, value: nil, table: nil)
    }

    private(set) static var shared: Resources!

    public static func string(_ key: String, value: String? = nil) -> String {
        shared.string(key, value: value)
    }

    // MARK: Main bundle location

    /// We initialize the resource bundles before we process options (so that we can report localized
    /// error messages about problems with the options) which means that we keep debug messages
    /// recording our tortuous initialization for later playback.
    ///
    private static var debugLog = [String]()
    
    private static func log(_ msg: String) {
        debugLog.append(msg)
    }

    public static func reportInitialization() {
        debugLog.forEach { logDebug($0) }
    }

    public static func initialize() {
        #if SWIFT_PACKAGE
        let mainBundle = spmFindMainBundle()
        #else
        let mainBundle = xcodeFindMainBundle()
        #endif

        log("Resource bundle path: \(mainBundle.bundlePath)")

        let localizationBundle = findLocalizationBundle(in: mainBundle)

        log("Localization bundle path: \(localizationBundle.bundlePath)")

        shared = Resources(bundle: mainBundle, localizationBundle: localizationBundle)
    }

    /// In Xcode world, the resource bundle is a "plugin" sub-bundle of the J2Lib framework bundle.
    /// This is (sort of) how the APIs want this to work.
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
            // Galaxies of room for improvement.

            if let langVar = ProcessInfo.processInfo.environment["LANG"],
                let match = langVar.re_match(#"^(.*)\.?"#) {
                let languageCountry = String(match[1])
                let language = String(languageCountry.prefix(2))

                log("Localization bundle: using LANG \(langVar) derived \(languageCountry), \(language)")

                for match in [languageCountry, language] {
                    if supported.contains(match) {
                        return match
                    }
                }
            }

            // No LANG (bare-bones docker image!) or unsupported LANG

            return nil
        }

        // As appears traditional: fall back to en...
        let chosen = preferredLanguage() ?? "en"
        let localizationURL = bundle.resourceURL!.appendingPathComponent("\(chosen).\(LPROJ)")
        return Bundle(url: localizationURL)!
    }
}
