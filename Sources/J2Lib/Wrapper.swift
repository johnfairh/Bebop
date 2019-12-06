//
//  Wrapper.swift
//  J2
//
//  Distributed under the MIT license, see LICENSE
//

import Foundation
import RubyGateway

public enum Main {
    public static func run() {
        print("Main.run, Ruby is: \(Ruby.version)")
    }
}
