//
//  main.swift
//  BebopCLI
//
//  Copyright 2019 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import BebopLib
import Foundation

extension CommandLine {
  public static func arguments() -> [String] {
    UnsafeBufferPointer(start: unsafeArgv, count: Int(argc)).lazy
      .compactMap { $0 }
      .compactMap { String(validatingUTF8: $0) }
  }
}

let exitStatus = Pipeline.main(argv: [String](CommandLine.arguments().dropFirst()))
exit(exitStatus)
