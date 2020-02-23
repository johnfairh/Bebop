//
//  TestGatherObjC.swift
//  J2Tests
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import XCTest
@testable import J2Lib
import SourceKittenFramework

private class System {
    let config: Config
    let gatherOpts: GatherOpts
    init() {
        config = Config()
        gatherOpts = GatherOpts(config: config)
    }
    func configure(_ cliOpts: [String]) throws -> GatherJob {
        try config.processOptions(cliOpts: cliOpts)
        let jobs = gatherOpts.jobs
        XCTAssertEqual(1, jobs.count)
        return gatherOpts.jobs.first!
    }
}

class TestGatherObjC: XCTestCase {
    override func setUp() {
        initResources()
    }

    #if !os(macOS)
    func testNoObjC() throws {
        let tmpDir = try TemporaryDirectory()
        let tmpFile = try tmpDir.createFile(name: "test.h")
        try "extern int fred;".write(to: tmpFile)

        let system = System()
        AssertThrows(try system.configure(["--objc-header-file=\(tmpFile.path)"]), OptionsError.self)
    }
    #else

    private func checkError(_ cliOpts: [String], line: UInt = #line) {
        let system = System()
        AssertThrows(try system.configure(cliOpts), OptionsError.self, line: line)
    }

    private func checkNotImplemented(_ cliOpts: [String], line: UInt = #line) {
        let system = System()
        AssertThrows(try system.configure(cliOpts), NotImplementedError.self, line: line)
    }

    func testBadOptions() {
        checkError(["--objc", "--build-tool=spm"])
        checkError(["--objc-direct"])
        checkError(["--objc-sdk=macosx"])
        checkError(["--objc-include-paths=/"])
        checkNotImplemented(["--objc-header=/foo.h", "--build-tool=spm"])
    }

    private func checkJob(_ cliOpts: [String], _ expectedJob: GatherJob, line: UInt = #line) throws {
        let system = System()
        let job = try system.configure(cliOpts)
        XCTAssertEqual(expectedJob, job, line: line)
    }

    func testJobOptions() throws {
        let tmpDir = try TemporaryDirectory()
        let tmpFile = try tmpDir.createFile(name: "test.h")
        try "extern int fred;".write(to: tmpFile)

        let tmpDirURL = URL(fileURLWithPath: tmpDir.directoryURL.path,
                            relativeTo: FileManager.default.currentDirectory)

        TestLogger.install()
        try checkJob(["--objc-header-file=\(tmpFile.path)"],
                 .objcDirect(moduleName: "Module",
                             headerFile: tmpFile,
                             includePaths: [],
                             sdk: .macosx,
                             buildToolArgs: [],
                             availabilityRules: GatherAvailabilityRules()))
        XCTAssertEqual(1, TestLogger.shared.diagsBuf.count)

        try checkJob(["--objc-header-file=\(tmpFile.path)", "--module=MyMod"],
                 .objcDirect(moduleName: "MyMod",
                             headerFile: tmpFile,
                             includePaths: [],
                             sdk: .macosx,
                             buildToolArgs: [],
                             availabilityRules: GatherAvailabilityRules()))

        try checkJob(["--objc-header-file=\(tmpFile.path)",
                      "--objc-sdk=iphoneos",
                      "--objc-include-paths=\(tmpDir.directoryURL.path)"],
                 .objcDirect(moduleName: "Module",
                             headerFile: tmpFile,
                             includePaths: [tmpDirURL],
                             sdk: .iphoneos,
                             buildToolArgs: [],
                             availabilityRules: GatherAvailabilityRules()))
    }

    #endif /* macOS */

    // Declaration formatting

    private func checkDeclaration(_ decl: String, _ name: String, _ rawKind: ObjCDeclarationKind,
                                  _ expectDecl: String, _ expectPieces: String, line: UInt = #line) {
        let dict: SourceKittenDict = [SwiftDocKey.parsedDeclaration.rawValue: decl,
                                      SwiftDocKey.name.rawValue: name]
        let kind = DefKind.from(key: rawKind.rawValue)!
        let builder = ObjCDeclarationBuilder(dict: dict, kind: kind)
        guard let built = builder.build() else {
            XCTFail("Couldn't build", line: line)
            return
        }
        XCTAssertEqual(expectDecl, built.declaration, "original: \(decl)", line: line)
        XCTAssertEqual(expectPieces, built.namePieces.flat, "originall: \(decl)", line: line)
    }

    func testStructDeclarations() {
        let classVariants = [
            "@interface Test : NSObject {\n  NSString *ivarName;\n}",
            "@interface Test : NSObject\n{\nNSString *ivarName;\n\n}\n\n\n@property NSString *propertyName;\n\n\n- (void)method;\n\n+ (void)classMethod;\n\n\n@end",
            "@interface Test : NSObject {}",
            "@interface Test : NSObject\n@end",
            "@interface Test : NSObject",
        ]
        classVariants.forEach { variant in
            checkDeclaration(variant, "Test", .class, "@interface Test : NSObject", "@interface #Test#")
        }
    }

    func testEnumDeclarations() {
        checkDeclaration("NS_ENUM(NSInteger, AEnum) {\n  a = 3,\n  b = 4\n}", "AEnum", .enum,
                         "NS_ENUM(NSInteger, AEnum)", "enum #AEnum#")
        checkDeclaration("typedef NS_ENUM(NSInteger, AEnum", "AEnum", .typedef,
                         "typedef NS_ENUM(NSInteger, AEnum)", "typedef #AEnum#")
        checkDeclaration("typedef enum AEnum AEnum", "AEnum", .typedef,
                         "typedef enum AEnum AEnum", "typedef #AEnum#")
    }

    func testPropertyDeclarations() {
        checkDeclaration("@property NSString *prop", "prop", .property,
                         "@property NSString *prop", "NSString *#prop#")
        checkDeclaration("@property (assign, readwrite, atomic) NSString *prop;", "prop", .property,
                         "@property NSString *prop", "NSString *#prop#")
        checkDeclaration("@property (assign, readwrite, nonatomic, nullable) NSImage *image;", "image", .property,
                         "@property (nonatomic, nullable) NSImage *image", "NSImage *#image#")
        checkDeclaration("@property (class, nonatomic, copy) NSUUID *identifier", "identifier", .property,
                         "@property (class, nonatomic, copy) NSUUID *identifier", "NSUUID *#identifier#")
        checkDeclaration("@property (readwrite, copy, nonatomic, class) NSUUID *identifier", "identifier", .property,
                         "@property (copy, nonatomic, class) NSUUID *identifier", "NSUUID *#identifier#")
    }

    func testMethodDeclarations() {
        checkDeclaration("+ method", "+method", .methodClass, "+ method", "+ #method#")
        checkDeclaration("+ method:(int) param", "+method:", .methodClass,
                         "+ method:(int) param", "+ #method#:(int) param")
        checkDeclaration("-method:(int) param and:(NSString *)name", "-method:and:", .methodInstance,
                         "-method:(int) param and:(NSString *)name", "-#method#:(int) param #and#:(NSString *)name")
        checkDeclaration("""
                         - methodName:(int) param1
                                  and:(string) param2
                              finally:(int) param3
                         """,
                         "-methodName:and:finally:",
                         .methodInstance,
                         """
                         - methodName:(int) param1
                                  and:(string) param2
                              finally:(int) param3
                         """,
                         """
                         - #methodName#:(int) param1
                                  #and#:(string) param2
                              #finally#:(int) param3
                         """)
    }

    func testSimpleDeclarations() {
        checkDeclaration("void cfunc(int)", "cfunc", .function,
                         "void cfunc(int)", "void #cfunc#(int)")
        checkDeclaration("int field", "field", .field,
                         "int field", "int #field#")
        checkDeclaration("@import Foundation", "Foundation", .moduleImport,
                         "@import Foundation", "#@import Foundation#")
    }

    // Deprecations

    private func checkDeprecations(_ dep: String?, _ exDep: String?, _ unav: String?, _ exUnav: String?, line: UInt = #line) {
        var dict = SourceKittenDict()
        dict[SwiftDocKey.parsedDeclaration.rawValue] = "@interface Fred";
        dict[SwiftDocKey.alwaysDeprecated.rawValue] = dep == nil ? false : true
        if let dep = dep, !dep.isEmpty {
            dict[SwiftDocKey.deprecationMessage.rawValue] = dep
        }
        dict[SwiftDocKey.alwaysUnavailable.rawValue] = unav == nil ? false : true
        if let unav = unav, !unav.isEmpty {
            dict[SwiftDocKey.unavailableMessage.rawValue] = unav
        }
        let kind = DefKind.from(key: ObjCDeclarationKind.class.rawValue)!
        let builder = ObjCDeclarationBuilder(dict: dict, kind: kind)
        guard let built = builder.build() else {
            XCTFail("Couldn't build", line: line)
            return
        }
        if let exDep = exDep {
            XCTAssertEqual(exDep, built.deprecation?.get("en"))
        } else {
            XCTAssertNil(built.deprecation)
        }
        if let exUnav = exUnav {
            XCTAssertEqual(exUnav, built.unavailability?.get("en"))
        } else {
            XCTAssertNil(built.unavailability)
        }
    }

    func testDeprecations() {
        checkDeprecations(nil, nil, nil, nil)
        checkDeprecations("", "Deprecated.", nil, nil)
        checkDeprecations("Msg", "Deprecated. Msg", nil, nil)
        checkDeprecations(nil, nil, "", "Unavailable.")
        checkDeprecations(nil, nil, "Msg.", "Unavailable. Msg.")
        checkDeprecations("Msg", "Deprecated. Msg", "Msg.", "Unavailable. Msg.")
    }

    // Misc error/weird paths

    func testErrorPaths() {
        let fieldKind = DefKind.from(key: ObjCDeclarationKind.field.rawValue)!
        let noDecl = ObjCDeclarationBuilder.init(dict: [:], kind: fieldKind)
        XCTAssertNil(noDecl.build())

        // Field without name
        let malformedFieldDict = [
            SwiftDocKey.parsedDeclaration.rawValue: "int confused",
            SwiftDocKey.name.rawValue: "missing"
        ]
        let oddField = ObjCDeclarationBuilder.init(dict: malformedFieldDict, kind: fieldKind)
        XCTAssertEqual("#int confused#", oddField.build()?.namePieces.flat)

        // Free function without name
        let funcKind = DefKind.from(key: ObjCDeclarationKind.function.rawValue)!
        let malformedFuncDict = [
            SwiftDocKey.parsedDeclaration.rawValue: "int confused(void)",
            SwiftDocKey.name.rawValue: "missing"
        ]
        let oddFunc = ObjCDeclarationBuilder.init(dict: malformedFuncDict, kind: funcKind)
        XCTAssertEqual("#int confused(void)#", oddFunc.build()?.namePieces.flat)

        // Method that we can't parse
        let methodKind = DefKind.from(key: ObjCDeclarationKind.methodInstance.rawValue)!
        let malformedMethodDict = [
            SwiftDocKey.parsedDeclaration.rawValue: "int confused()",
            SwiftDocKey.name.rawValue: "missing"
        ]
        let oddMethod = ObjCDeclarationBuilder.init(dict: malformedMethodDict, kind: methodKind)
        XCTAssertEqual("#int confused()#", oddMethod.build()?.namePieces.flat)
    }
}