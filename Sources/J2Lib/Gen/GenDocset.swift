//
//  GenDocset.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SQLite

public final class GenDocset: Configurable {
    let docsetPathOpt = PathOpt(l: "docset-path").help("PATH").hidden
    let docsetModuleNameOpt = StringOpt(l: "docset-module-name").help("MODULENAME")
    let published: Published

    /// Module Name to use for the docset - defaults to one of the source modules
    var moduleName: String {
        if let docsetModuleName = docsetModuleNameOpt.value {
            return docsetModuleName
        }
        return published.moduleNames.first!
    }

    init(config: Config) {
        published = config.published
        config.register(self)
    }

    func checkOptions() throws {
        if docsetPathOpt.configured {
            logWarning(.localized(.wrnDocsetPath))
        }
    }

    static let DOCSET_TOP = "docsets"
    static let DOCSET_SUFFIX = ".docset"

    func generate(outputURL: URL, items: [Item]) throws {
        let docsetTopURL = outputURL.appendingPathComponent(Self.DOCSET_TOP)
        let docsetDirURL = docsetTopURL.appendingPathComponent("\(moduleName)\(Self.DOCSET_SUFFIX)")
        logDebug("Docset: cleaning any old content")
        try? FileManager.default.removeItem(at: docsetTopURL)

        try copyDocs(outputURL: outputURL, docsetDirURL: docsetDirURL)
        try createPList(docsetDirURL: docsetDirURL)
    }

    /// Copy over the files
    func copyDocs(outputURL: URL, docsetDirURL: URL) throws {
        logDebug("Docset: copying up site")

        let docsTargetURL = docsetDirURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Documents")

        try FileManager.default.createDirectory(atPath: docsTargetURL.path, withIntermediateDirectories: true)

        // Exclude ourselves and any secondary localizations
        let skipFiles = Set([Self.DOCSET_TOP] + Localizations.shared.others.map(\.tag))

        try Glob.files(.init(outputURL.appendingPathComponent("*").path)).forEach { sourceURL in
            let filename = sourceURL.lastPathComponent
            if !skipFiles.contains(filename) {
                let targetURL = docsTargetURL.appendingPathComponent(filename)
                try FileManager.default.copyItem(at: sourceURL, to: targetURL)
            }
        }
    }

    /// Create the plist
    func createPList(docsetDirURL: URL) throws {
        logDebug("Docset: creating plist")

        let lcModuleName = moduleName.lowercased()
        let plist = """
                    <?xml version="1.0" encoding="UTF-8"?>
                    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
                    <plist version="1.0">
                      <dict>
                        <key>CFBundleIdentifier</key>
                          <string>com.bebop.\(lcModuleName)</string>
                        <key>CFBundleName</key>
                          <string>\(moduleName)</string>
                        <key>DocSetPlatformFamily</key>
                          <string>\(lcModuleName)</string>
                        <key>isDashDocset</key>
                          <true/>
                        <key>dashIndexFilePath</key>
                          <string>index.html</string>
                        <key>isJavaScriptEnabled</key>
                          <true/>
                      </dict>
                    </plist>
                    """
//        <key>DashDocSetFamily</key>
//          <string>dashtoc</string>
//        <key>DashDocSetPlayUrl</key>
//          <string>url</string>
        let url = docsetDirURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Info.plist")
        try plist.write(to: url)
    }
}
