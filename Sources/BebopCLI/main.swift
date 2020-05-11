//
//  main.swift
//  BebopCLI
//
//  Copyright 2019 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import BebopLib
import Foundation

let exitStatus = Pipeline.main(argv: [String](CommandLine.arguments.dropFirst()))
exit(exitStatus)
