//
//  main.swift
//  J2CLI
//
//  Copyright 2019 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import J2Lib
import Foundation

let exitStatus = Pipeline.main(argv: [String](CommandLine.arguments.dropFirst()))
exit(exitStatus)
