//
//  CLIEntry.swift
//  J2Lib
//
//  Copyright 2019 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
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
