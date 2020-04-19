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
    let pathOpt = PathOpt(l: "docset-path").help("PATH").hidden
    let moduleNameOpt = StringOpt(l: "docset-module-name").help("MODULENAME")
    let playgroundURLOpt = StringOpt(l: "docset-playground-url").help("PLAYGROUNDURL")
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
        try createIndex(docsetDirURL: docsetDirURL, items: items)
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

        let playgroundKey: String
        if let playgroundURL = playgroundURLOpt.value {
            playgroundKey = """
                            <key>DashDocSetPlayURL</key>
                              <string>\(playgroundURL)</string>
                            """
        } else {
            playgroundKey = ""
        }

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
