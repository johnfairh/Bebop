//
//  CLIEntry.swift
//  J2Lib
//
//  Distributed under the MIT license, see LICENSE
//

import Foundation

public enum CLIEntry {
    public static func run(arguments: [String]) -> Int32 {
        do {
            let jazzy = try RubyJazzy.create(scriptName: "J2", cliArguments: arguments)
            try jazzy.run()
            return 0
        } catch {
            print("Ruby failure: \(error)")
            return 1
        }
    }
}
