//
//  CLIEntry.swift
//  J2Lib
//
//  Copyright 2019 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import Yams

public enum CLIEntry {
    public static func run(arguments: [String]) -> Int32 {
        do {
            let dictionary: [String: Any] = ["key": "value"]
            let mapYAML: String = try Yams.dump(object: dictionary)
            print(mapYAML)
            return 0
        } catch {
            print("Failure: \(error)")
            return 1
        }
    }
}
