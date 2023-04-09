//
//  TestDeclPrinter.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import XCTest
@testable import BebopLib

/// Checks for SwiftFormat embed

class TestDeclPrinter: XCTestCase {
    func testAssumptions() {
        TestLogger.install()
        TestLogger.shared.logger.activeLevels = Logger.allLevels

        // Doesn't understand types without bodies
        let typedecl = "private class Fred<T>: Jane where T: Codable"
        XCTAssertEqual(typedecl, DeclPrinter.format(swift: typedecl))
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)

        // *Does* understand functions without bodies
        let funcdecl = "func f(a b: Int)"
        XCTAssertEqual(funcdecl, DeclPrinter.format(swift: funcdecl))
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)

        // **does - swift 5.8** understand accessor annotations
        let vardecl = "private var a: Int { get set }"
        XCTAssertEqual(vardecl, DeclPrinter.format(swift: vardecl))
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)

        // ...including subscripts
        let subsdecl = "subscript(index: Int) -> String { get set }"
        XCTAssertEqual(subsdecl, DeclPrinter.format(swift: subsdecl))
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)
    }

    // VarDecl fixups
    func testVar() {
        TestLogger.install()
        TestLogger.shared.logger.activeLevels = Logger.allLevels

        let vardecl = "private var a: Int { get set }"
        XCTAssertEqual(vardecl, DeclPrinter.formatVar(swift: vardecl))
        XCTAssertEqual(0, TestLogger.shared.diagsBuf.count)

        let vardecl2 = "override public private(set) var a: Int { get }"
        XCTAssertEqual(vardecl2, DeclPrinter.formatVar(swift: vardecl2))
        XCTAssertEqual(0, TestLogger.shared.diagsBuf.count)
    }

    // Structural fixups
    func testStructural() {
        TestLogger.install()
        TestLogger.shared.logger.activeLevels = Logger.allLevels

        let typedecl = "private class Fred<T>: Jane where T: Codable"
        XCTAssertEqual(typedecl, DeclPrinter.formatStructural(swift: typedecl))
        XCTAssertEqual(0, TestLogger.shared.diagsBuf.count)

        let typedecl2 = """
                        private class Fred<T>:
                            Jane
                        where
                            T: Codable
                        """
        XCTAssertEqual(typedecl2, DeclPrinter.formatStructural(swift: typedecl2))
        XCTAssertEqual(0, TestLogger.shared.diagsBuf.count)
    }

    // Some actual formatting
    func testFormatting() {
        TestLogger.install()
        TestLogger.shared.logger.activeLevels = Logger.allLevels

        let longType = "open class PersistentCloudKitContainer: NSPersistentCloudKitContainer, PersistentContainerMigratable, PersistentContainerProtocol, LogMessageEmitter"
        let expected = """
                       open class PersistentCloudKitContainer: NSPersistentCloudKitContainer,
                           PersistentContainerMigratable, PersistentContainerProtocol,
                           LogMessageEmitter
                       """
        XCTAssertEqual(expected, DeclPrinter.formatStructural(swift: longType))

        let longFunc = "open override func loadPersistentStores(completionHandler block: @escaping (NSPersistentStoreDescription, Error?) -> ())"
        let expected2 = """
                        open override func loadPersistentStores(
                            completionHandler block: @escaping (NSPersistentStoreDescription, Error?) ->
                                Void)
                        """
        XCTAssertEqual(expected2, DeclPrinter.format(swift: longFunc))
    }
}
