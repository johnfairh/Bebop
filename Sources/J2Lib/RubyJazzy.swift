//
//  RubyJazzy.swift
//  J2Lib
//
//  Copyright 2019 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import RubyGateway

/// Wrapper of the Ruby jazzy gem.  To be gradually replaced.
struct RubyJazzy {
    /// `Jazzy::Config` Ruby module
    let configModule: RbObject

    /// `Jazzy::DocBuilder` Ruby module
    let docBuilderModule: RbObject

    /// Use `RubyJazzy.create(...)` to better handle exceptions....
    private init(configModule: RbObject, docBuilderModule: RbObject) {
        self.configModule = configModule
        self.docBuilderModule = docBuilderModule
    }

    /// Set up Ruby and initialize the top modules, first part of `jazzy.rb`.
    static func create(scriptName: String, cliArguments: [String]) throws -> RubyJazzy {
        try Ruby.require(filename: "jazzy")
        Ruby.scriptName = scriptName
        try Ruby.setArguments(cliArguments)

        let configModule = try Ruby.get("Jazzy::Config")
        let docBuilderModule = try Ruby.get("Jazzy::DocBuilder")

        return RubyJazzy(configModule: configModule, docBuilderModule: docBuilderModule)
    }

    /// Run jazzy: parse the config and build the site, second part of `jazzy.rb`
    func run() throws {
        let config = try configModule.call("parse!")
        try configModule.setAttribute("instance", newValue: config)
        try docBuilderModule.call("build", args: [config])
    }
}
