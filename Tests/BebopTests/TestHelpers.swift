//
//  TestHelpers.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import XCTest
@testable import BebopLib
import SourceKittenFramework

/// Execute some code and check it throws a particular category of error.
/// 
/// - Parameters:
///   - expression: code to run
///   - expectedError: expected `BBError` to be thrown
public func AssertThrows<Err, Ret>(_ expression: @autoclosure () throws -> Ret,
                                   _ expectedError: Err.Type,
                                   _ message: String = "",
                                   file: StaticString = #file,
                                   line: UInt = #line) {
    XCTAssertThrowsError(try expression(), message, file: file, line: line, { actualError in
        guard let bbError = actualError as? Err else {
            XCTFail("\(actualError) is not \(expectedError)", file: file, line: line)
            return
        }
        if let dbgErr = bbError as? CustomDebugStringConvertible {
            print(dbgErr.debugDescription)
        }
    })
}

public func AssertThrows<Ret>(_ expression: @autoclosure () throws -> Ret,
                              _ expectedError: L10n.Localizable,
                              _ message: String = "",
                              file: StaticString = #file,
                              line: UInt = #line) {
    XCTAssertThrowsError(try expression(), message, file: file, line: line, { actualError in
        guard let bbError = actualError as? BBError else {
            XCTFail("\(actualError) is not a BBError", file: file, line: line)
            return
        }
        XCTAssertEqual(expectedError, bbError.key)
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

    func with(swiftName: String?) -> Self {
        guard let swiftName = swiftName else { return self }
        return with(field: .swiftName, value: swiftName)
    }

    func with(swiftDeclaration: String) -> Self {
        return with(field: .swiftDeclaration, value: swiftDeclaration)
    }
    #endif

    func with(decl: String) -> Self {
        with(field: "key.fully_annotated_decl", value: "<o>\(decl)</o>")
            .with(field: "key.parsed_declaration", value: decl)
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

    static func mkMethod(fullName: String, decl: String) -> Self {
        SourceKittenDict()
            .with(kind: .functionMethodInstance)
            .with(name: fullName)
            .with(decl: decl)
            .with(usr: decl)
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

    static func mkObjCClass(name: String, swiftName: String? = nil) -> Self {
        SourceKittenDict()
            .with(okind: .class)
            .with(name: name)
            .with(decl: "@interface \(name)")
            .with(usr: name)
            .with(swiftName: swiftName)
    }

    static func mkObjCProperty(name: String, swiftName: String? = nil) -> Self {
        SourceKittenDict()
            .with(okind: .property)
            .with(name: name)
            .with(decl: "@property (atomic) \(name)")
            .with(usr: name)
            .with(swiftName: swiftName)
    }

    static func mkObjCMethod(name: String, swiftName: String? = nil) -> Self {
        SourceKittenDict()
            .with(okind: .methodInstance)
            .with(name: name)
            .with(decl: "- (void) \(name.dropFirst())")
            .with(usr: name)
            .with(swiftName: swiftName)
    }
    #endif

    static func mkFile() -> Self {
        [ "key.diagnostic_stage" : "parse" ]
    }

    // Promotion

    func asGatherDef(availability: String? = nil) -> GatherDef {
        let rules = Gather.Availability(defaults: availability.flatMap { [$0] } ?? [],
                                        ignoreAttr: false)
        let rootDef = GatherDef(sourceKittenDict: self,
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
    /// Test helper
    convenience init(sourceKittenDict: SourceKittenDict, children: [GatherDef]) {
        self.init(children: children,
                  sourceKittenDict: sourceKittenDict,
                  kind: nil,
                  swiftDeclaration: nil,
                  objCDeclaration: nil,
                  documentation: nil,
                  localizationKey: nil,
                  translatedDocs: nil)
    }

    func asPass(moduleName: String = "module", passIndex: Int = 0, pathName: String = "pathname") -> GatherModulePass {
        GatherModulePass(moduleName: moduleName,
                         passIndex: passIndex,
                         imported: false,
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

enum TestSymbolGraph {
    static let path = "/Users/johnf/project/swift-source/build/jfdev/swift-macosx-x86_64/bin/swift-symbolgraph-extract"

    static var isMyLaptop: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    static func useCustom(path: String? = nil) {
        let tool = path ?? self.path
        setenv("BEBOP_SWIFT_SYMBOLGRAPH_EXTRACT", strdup(tool), 1)
    }

    static func reset() {
        unsetenv("BEBOP_SWIFT_SYMBOLGRAPH_EXTRACT")
    }
}
