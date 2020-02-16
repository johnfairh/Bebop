//
//  TestHelpers.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib
import SourceKittenFramework

/// Execute some code and check it throws a particular category of error.
/// 
/// - Parameters:
///   - expression: code to run
///   - expectedError: expected `J2Lib.Error` to be thrown - uses `J2Lib.Error.sameCategory(other:)`
///                    to compare, meaning text payload is not compared - just the enum case.
public func AssertThrows<Err, Ret>(_ expression: @autoclosure () throws -> Ret,
                                   _ expectedError: Err.Type,
                                   _ message: String = "",
                                   file: StaticString = #file,
                                   line: UInt = #line) where Err: CustomDebugStringConvertible {
    XCTAssertThrowsError(try expression(), message, file: file, line: line, { actualError in
        guard let j2Error = actualError as? Err else {
            XCTFail("\(actualError) is not \(expectedError)", file: file, line: line)
            return
        }
        print(j2Error.debugDescription)
    })
}

/// Probably can delete this now...
func Do(code: () throws -> Void) {
    do {
        try code()
    } catch {
        XCTFail("Unexpected error thrown: \(error)")
    }
}

// Logger drop-in to log to string buffers
//
final class TestLogger {
    var messageBuf = [String]()
    var diagsBuf = [String]()
    var outputBuf = [String]()
    var logger = Logger()
    var expectNothing = false
    var expectNoDiags = false
    var expectNoMessages = false
    var expectNoOutput = false

    init() {
        logger.logHandler = { m, d in
            XCTAssertFalse(self.expectNothing)
            switch d {
            case .diagnostic:
                XCTAssertFalse(self.expectNoDiags)
                self.diagsBuf.append(m)
            case .message:
                XCTAssertFalse(self.expectNoMessages)
                self.messageBuf.append(m)
            case .output:
                XCTAssertFalse(self.expectNoOutput)
                self.outputBuf.append(m)
            }
        }
    }

    static var shared = TestLogger()

    static func install() {
        let testLogger = TestLogger()
        shared = testLogger
        Logger.shared = testLogger.logger
    }

    static func uninstall() {
        Logger.shared = Logger()
    }
}

extension XCTestCase {
    /// Set up so that the code can find the resources - needed for SPM
    /// where the built pieces are scattered.
    func prepareResourceBundle() {
        #if SWIFT_PACKAGE
        let bundlePath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .path
        setenv(Resources.BUNDLE_ENV_VAR, strdup(bundlePath), 1)
        #endif
    }

    func initResources() {
        prepareResourceBundle()
        Resources.initialize()
        Localizations.shared = Localizations()
    }

    var fixturesURL: URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }
}

//
// Helpers for writing decl tests
//
extension SourceKittenDict {
    func with(field: SwiftDocKey, value: SourceKitRepresentable) -> Self {
        with(field: field.rawValue, value: value)
    }

    func with(field: String, value: SourceKitRepresentable) -> Self {
        var copy = self
        copy[field] = value
        return copy
    }

    func with(name: String) -> Self {
        with(field: .name, value: name)
    }

    func with(kind: SwiftDeclarationKind) -> Self {
        with(field: .kind, value: kind.rawValue)
    }

    #if os(macOS)
    func with(okind: ObjCDeclarationKind) -> Self {
        with(field: .kind, value: okind.rawValue)
    }
    #endif

    func with(decl: String) -> Self {
        with(field: "key.fully_annotated_decl", value: "<o>\(decl)</o>")
    }

    func with(comment: String) -> Self {
        with(field: .documentationComment, value: comment)
    }

    func with(children: [SourceKittenDict]) -> Self {
        with(field: .substructure, value: children)
    }

    // Factories

    static func mkClass(name: String, docs: String = "") -> Self {
        SourceKittenDict()
            .with(kind: .class)
            .with(name: name)
            .with(decl: "class \(name)")
            .with(comment: docs)
    }

    static func mkStruct(name: String, docs: String = "") -> Self {
        SourceKittenDict()
            .with(kind: .struct)
            .with(name: name)
            .with(decl: "struct \(name)")
            .with(comment: docs)
    }

    static func mkInstanceVar(name: String, docs: String = "") -> Self {
        SourceKittenDict()
            .with(kind: .varInstance)
            .with(name: name)
            .with(decl: "var \(name)")
            .with(comment: docs)
    }

    static func mkGlobalVar(name: String, docs: String = "") -> Self {
        SourceKittenDict()
            .with(kind: .varGlobal)
            .with(name: name)
            .with(decl: "var \(name)")
            .with(comment: docs)
    }

    static func mkSwiftMark(text: String) -> Self {
        SourceKittenDict()
            .with(field: .kind, value: "source.lang.swift.syntaxtype.comment.mark")
            .with(name: text)
    }

    #if os(macOS)
    static func mkObjCMark(text: String) -> Self {
        SourceKittenDict()
            .with(okind: .mark)
            .with(name: text)
    }
    #endif

    static func mkFile() -> Self {
        [ "key.diagnostic_stage" : "parse" ]
    }

    // Promotion

    var asGatherDef: GatherDef {
        GatherDef(sourceKittenDict: self, file: nil, availabilityRules: GatherAvailabilityRules())
    }

    var asGatherPasses: [GatherModulePass] {
        asGatherDef.asPasses()
    }
}

extension GatherDef {

    func asPass(moduleName: String = "module", pathName: String = "pathname") -> GatherModulePass {
        GatherModulePass(moduleName: moduleName,
                         passIndex: 0,
                         files: [(pathName, self)])
    }

    func asPasses(moduleName: String = "module", pathName: String = "pathname") -> [GatherModulePass] {
        [asPass(moduleName: moduleName, pathName: pathName)]
    }
}
