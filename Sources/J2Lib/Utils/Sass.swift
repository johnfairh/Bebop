//
//  Sass.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import J2Libsass

// Couldn't find an even slightly-convincing Swift wrapper for this.
// Future project?  Just a quick wrapper here for the basic function we want.
//
// Code samples are misleading over memory model, just bodging this through
// for now without much study.

enum Sass {
    final class FileContext {
        let context: OpaquePointer

        init(file: URL) throws {
            guard let context = sass_make_file_context(file.path) else {
                throw J2Error("sass_make_file_context \(file.path) failed.")
            }
            self.context = context
        }

        func compile() throws -> String {
            let rc = sass_compile_file_context(context)
            guard rc == 0 else {
                var errMsg = "(??)"
                if let err = sass_context_get_error_message(context) {
                    errMsg = String(cString: err)
                }
                throw J2Error(.errSassCompile, rc, errMsg)
            }
            guard let output = sass_context_get_output_string(context) else {
                throw J2Error("sass_context_get_output_string failed.")
            }
            return String(cString: output)
        }

        deinit {
            sass_delete_file_context(context)
        }
    }

    final class Options {
        let options: OpaquePointer

        init(context: FileContext) throws {
            guard let options = sass_file_context_get_options(context.context) else {
                throw J2Error("sass_file_context_get_options failed.")
            }
            self.options = options
        }

        func set(inputPath: URL) {
            sass_option_set_input_path(options, inputPath.path)
        }

        func set(includeDirectories: [URL]) {
            let path = includeDirectories.map(\.path).joined(separator: ";")
            sass_option_set_include_path(options, path)
        }

        func set(outputStyle: Sass_Output_Style) {
            sass_option_set_output_style(options, outputStyle)
        }
    }

    static func render(scssFileURL: URL) throws -> String {
        let context = try FileContext(file: scssFileURL)
        let options = try Options(context: context)
        options.set(inputPath: scssFileURL)
        options.set(includeDirectories: [scssFileURL.deletingLastPathComponent()])
        options.set(outputStyle: SASS_STYLE_NESTED)
        return try context.compile()
    }

    /// More useful file->file wrapper with some file-naming defaults
    static func renderInPlace(scssFileURL: URL) throws {
        let scssFilename = scssFileURL.lastPathComponent
        let cssFilename: String
        if scssFilename.hasSuffix(".css.scss") {
            cssFilename = String(scssFilename.dropLast(5))
        } else {
            cssFilename = scssFilename.re_sub("scss$", with: "css")
        }
        let css = try render(scssFileURL: scssFileURL)
        try css.write(to: scssFileURL
            .deletingLastPathComponent()
            .appendingPathComponent(cssFilename))
    }
}
