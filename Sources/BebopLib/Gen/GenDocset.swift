//
//  GenDocset.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation
import SQLite

public final class GenDocset: Configurable {
    let pathOpt = PathOpt(l: "docset-path").help("PATH").hidden
    let moduleNameOpt = StringOpt(l: "docset-module-name").help("MODULENAME")
    let playgroundURLOpt = URLOpt(l: "docset-playground-url").help("PLAYGROUNDURL")
    let iconPathOpt = PathOpt(l: "docset-icon").help("ICONPATH")
    let icon2xPathOpt = PathOpt(l: "docset-icon-2x").help("ICONPATH")
    let published: Published

    /// Module Name to use for the docset - defaults to one of the source modules
    var moduleName: String {
        if let docsetModuleName = moduleNameOpt.value {
            return docsetModuleName
        }
        return published.moduleNames.first!
    }

    init(config: Config) {
        published = config.published
        config.register(self)
    }

    func checkOptions() throws {
        if pathOpt.configured {
            logWarning(.wrnDocsetPath)
        }
        func checkIconPathOpt(_ opt: PathOpt) throws {
            try opt.checkIsFile()
            if let url = opt.value,
                !url.path.hasSuffix(".png") {
                throw BBError(.errCfgDocsetIcon, url.path)
            }
        }
        try checkIconPathOpt(iconPathOpt)
        try checkIconPathOpt(icon2xPathOpt)
    }

    static let DOCSET_TOP = "docsets"
    static let DOCSET_SUFFIX = ".docset"

    func generate(outputURL: URL, deploymentURL: URL?, items: [Item]) throws {
        let docsetName = moduleName + Self.DOCSET_SUFFIX
        logInfo(.msgDocsetProgress, docsetName)

        let docsetTopURL = outputURL.appendingPathComponent(Self.DOCSET_TOP)
        let docsetDirURL = docsetTopURL.appendingPathComponent(docsetName)
        try? FileManager.default.removeItem(at: docsetTopURL)

        try copyDocs(outputURL: outputURL, docsetDirURL: docsetDirURL)
        try copyIcons(docsetDirURL: docsetDirURL)
        try createPList(docsetDirURL: docsetDirURL, deploymentURL: deploymentURL)
        try createIndex(docsetDirURL: docsetDirURL, items: items)
        createArchive(docsetTopURL: docsetTopURL, docsetName: docsetName)
        if let deploymentURL = deploymentURL,
            let version = published.docsVersion {
            try createFeedXML(docsetTopURL: docsetTopURL, deploymentURL: deploymentURL, version: version)
        } else {
            logDebug("Docset: skipping feed XML creation, not enough metadata.")
        }
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

        try outputURL.filesMatching(.all).forEach { sourceURL in
            let filename = sourceURL.lastPathComponent
            if !skipFiles.contains(filename) {
                let targetURL = docsTargetURL.appendingPathComponent(filename)
                try FileManager.default.copyItem(at: sourceURL, to: targetURL)
            }
        }
    }

    /// Optional icons
    func copyIcons(docsetDirURL: URL) throws {
        func doCopyIcon(opt: PathOpt, name: String) throws {
            guard let sourceURL = opt.value else {
                return
            }
            let destURL = docsetDirURL.appendingPathComponent(name)
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
        }
        try doCopyIcon(opt: iconPathOpt, name: "icon.png")
        try doCopyIcon(opt: icon2xPathOpt, name: "icon@2x.png")
    }

    /// Create the plist
    func createPList(docsetDirURL: URL, deploymentURL: URL?) throws {
        logDebug("Docset: creating plist")

        let lcModuleName = moduleName.lowercased()

        func itemXML(key: String, for value: URL?) -> String {
            guard let value = value?.absoluteString else {
                return ""
            }
            return """
                   <key>\(key)</key>
                      <string>\(value)</string>
                   """
        }

        let playgroundKey = itemXML(key: "DashDocSetPlayURL",
                                    for: playgroundURLOpt.value)
        let deploymentKey = itemXML(key: "DashDocSetFallbackURL",
                                    for: deploymentURL)

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
                        <key>DashDocSetFamily</key>
                          <string>dashtoc</string>
                        \(playgroundKey)
                        \(deploymentKey)
                      </dict>
                    </plist>
                    """

        let url = docsetDirURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Info.plist")
        try plist.write(to: url)
    }

    /// Create the index database
    func createIndex(docsetDirURL: URL, items: [Item]) throws {
        logDebug("Docset: creating index DB")

        let url = docsetDirURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Resources")
            .appendingPathComponent("docSet.dsidx")
        let db = try DocsetDb(filepath: url.path)
        let visitor = DocsetVisitor(db: db)
        try visitor.walk(items: items)
    }

    /// Create the tgz
    func createArchive(docsetTopURL: URL, docsetName: String) {
        logDebug("Docset: creating tarfile")

        let tarArgs = ["tar", "--exclude='.DS_Store'", "-czf", moduleName + ".tgz", docsetName]
        let results = Exec.run("/usr/bin/env", tarArgs,
                               currentDirectory: docsetTopURL.path,
                               stderr: .merge)
        if results.terminationStatus != 0 {
            logWarning(.wrnDocsetTarfile, results.failureReport)
        }
    }

    /// Create the feed doc
    func createFeedXML(docsetTopURL: URL, deploymentURL: URL, version: String) throws {
        logDebug("Docset: creating feed XML")

        let tarFileURL = deploymentURL
            .appendingPathComponent("docsets")
            .appendingPathComponent("\(moduleName).tgz")

        let xml = """
                  <entry>
                    <version>\(version)</version>
                    <url>\(tarFileURL.absoluteString)</url>
                  </entry>
                  """

        let xmlFileURL = docsetTopURL.appendingPathComponent("\(moduleName).xml")
        try xml.write(to: xmlFileURL)
    }

    /// Where the feed XML file will be given a docs deployment URL
    func feedURLFrom(deploymentURL: URL) -> URL {
        deploymentURL
            .appendingPathComponent("docsets")
            .appendingPathComponent("\(moduleName).xml")
    }
}

// MARK: Index DB

struct DocsetVisitor: ItemVisitorProtocol {
    let db: DocsetDb

    func visit(defItem: DefItem, parents: [Item]) throws {
        try db.add(item: defItem)
    }

    func visit(groupItem: GroupItem, parents: [Item]) throws {
        try db.add(item: groupItem)
    }

    func visit(guideItem: GuideItem, parents: [Item]) throws {
        try db.add(item: guideItem)
    }

    func visit(readmeItem: ReadmeItem, parents: [Item]) throws {
        // don't put the readme in the index
    }
}

struct DocsetDb {
    let db: Connection
    let id: Expression<Int64>
    let name, type, path: Expression<String>
    let table: Table

    init(filepath: String) throws {
        db = try Connection(filepath)
        id = Expression<Int64>("id")
        name = Expression<String>("name")
        type = Expression<String>("type")
        path = Expression<String>("path")
        table = Table("searchIndex")

        try db.run(table.create { t in
            t.column(id, primaryKey: true)
            t.column(name)
            t.column(type)
            t.column(path)
        })

        try db.run(table.createIndex(name, type, path, unique: true))
    }

    func add(item: Item) throws {
        try db.run(
            table.insert(or: .ignore,
                         name <- item.name,
                         type <- item.dashKind,
                         path <- item.url.dashFilepath)
        )
    }
}
