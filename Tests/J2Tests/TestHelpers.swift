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

    func without(field: SwiftDocKey) -> Self {
        without(field: field.rawValue)
    }

    func with(field: String, value: SourceKitRepresentable) -> Self {
        var copy = self
        copy[field] = value
        return copy
    }

    func without(field: String) -> Self {
        var copy = self
        copy.removeValue(forKey: field)
        return copy
    }

    func with(name: String) -> Self {
        with(field: .name, value: name)
    }

    func with(kind: SwiftDeclarationKind) -> Self {
        with(field: .kind, value: kind.rawValue)
    }

    func with(usr: String) -> Self {
        with(field: .usr, value: usr)
    }

    func with(typename: String) -> Self {
        with(field: .typeName, value: typename)
    }

    func with(accessibility: DefAcl) -> Self {
        with(field: "key.accessibility", value: "source.lang.swift.accessibility.\(accessibility.rawValue)")
    }

    func with(docs: String) -> Self {
        with(field: .documentationComment, value: docs)
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

    func with(xmlDocs: String) -> Self {
        with(field: .fullXMLDocs, value: xmlDocs)
    }

    func with(overrides: [String]) -> Self {
        let dicts = overrides.map { ["key.usr" : $0] }
        return with(field: "key.overrides", value: dicts)
    }

    func with(children: [SourceKittenDict]) -> Self {
        with(field: .substructure, value: children)
    }

    // Factories

    static func mkClass(name: String) -> Self {
        SourceKittenDict()
            .with(kind: .class)
            .with(name: name)
            .with(decl: "class \(name)")
            .with(usr: name)
    }

    static func mkProtocol(name: String) -> Self {
        SourceKittenDict()
            .with(kind: .protocol)
            .with(name: name)
            .with(decl: "protocol \(name)")
            .with(usr: name)
    }

    static func mkExtension(name: String) -> Self {
        SourceKittenDict()
            .with(kind: .extension)
            .with(name: name)
            .with(decl: "extension \(name)")
            .with(usr: name)
    }

    static func mkStruct(name: String) -> Self {
        SourceKittenDict()
            .with(kind: .struct)
            .with(name: name)
            .with(decl: "struct \(name)")
            .with(usr: name)
    }

    static func mkInstanceVar(name: String) -> Self {
        SourceKittenDict()
            .with(kind: .varInstance)
            .with(name: name)
            .with(decl: "var \(name)")
            .with(usr: name)
    }

    static func mkGlobalVar(name: String) -> Self {
        SourceKittenDict()
            .with(kind: .varGlobal)
            .with(name: name)
            .with(decl: "var \(name)")
            .with(usr: name)
    }

    static func mkMethod(name: String) -> Self {
        SourceKittenDict()
            .with(kind: .functionMethodInstance)
            .with(name: name)
            .with(decl: "func \(name)()")
            .with(usr: name)
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

    func asGatherDef(availability: String? = nil) -> GatherDef {
        let rules = Gather.Availability(defaults: availability.flatMap { [$0] } ?? [],
                                        ignoreAttr: false)
        var rootDef = GatherDef(sourceKittenDict: self,
                                parentNameComponents: [],
                                file: nil,
                                availability: rules)!
        func fixDocComment(def: GatherDef) {
            if let flatDocs = def.documentation {
                def.translatedDocs.set(tag: Localizations.shared.main.tag, docs: flatDocs)
            }
            def.children.forEach { fixDocComment(def: $0) }
        }
        fixDocComment(def: rootDef)
        return rootDef
    }

    var asGatherPasses: [GatherModulePass] {
        asGatherDef().asPasses()
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

    static func mkFile(children: [GatherDef]) -> GatherDef {
        let fileDict = SourceKittenDict.mkFile()
        return GatherDef(sourceKittenDict: fileDict, children: children)
    }
}
