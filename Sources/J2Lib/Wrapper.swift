//
//  Wrapper.swift
//  J2
//
//  Distributed under the MIT license, see LICENSE
//

import Foundation
import RubyGateway

public enum Main {
    public static func run(arguments: [String]) {
        do {
            Ruby.scriptName = "J2"
            let rubyArgv = try Ruby.get("ARGV")
            arguments.enumerated().forEach { (arg) in
                rubyArgv[arg.0] = RbObject(arg.1)
            }
            try Ruby.require(filename: "jazzy")
            let jazzyConfigModule = try Ruby.get("Jazzy::Config")
            let config = try jazzyConfigModule.call("parse!")
            try jazzyConfigModule.setAttribute("instance", newValue: config)

            let jazzyDocBuilderModule = try Ruby.get("Jazzy::DocBuilder")
            try jazzyDocBuilderModule.call("build", args: [config])
        } catch {
            print("Ruby failure: \(error)")
        }
    }
}
