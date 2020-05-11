//
//  GenSiteRecord.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation

struct GenSiteRecord {
    let published: Published

    init(config: Config) {
        published = config.published
    }

    struct Data: Codable {
        let version: String
        let modules: [String]
    }

    static let FILENAME = "site.json"

    func writeRecord(outputURL: URL) throws {
        logDebug("Writing site.json")
        let data = Data(version: Version.bebopLibVersion,
                        modules: published.moduleNames)
        try JSON.encode(data).write(to: outputURL.appendingPathComponent(Self.FILENAME))
    }

    static func fetchRecord(from siteURL: URL) throws -> Data {
        let data = try siteURL.appendingPathComponent(Self.FILENAME).fetch()
        return try JSONDecoder().decode(Data.self, from: data)
    }
}
