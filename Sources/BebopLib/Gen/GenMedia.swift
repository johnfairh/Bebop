//
//  GenMedia.swift
//  BebopLib
//
//  Copyright 2020 Bebop Authors
//  Licensed under MIT (https://github.com/johnfairh/Bebop/blob/master/LICENSE)
//

import Foundation

/// Store and namer of opaque files (images in practice) that are stored in the docs,
/// potentially localized, and referenced from html/markdown.
///
/// Gotcha of monolithic Swift application -- can't call this 'Resources' 'cos I already have one of those!
///
final class GenMedia: Configurable {
    private let mediaOpt = GlobListOpt(l: "media").help("FILEPATHGLOB1,FILEPATHGLOB2,...")

    typealias Files = [String : Localized<URL>]

    private(set) var mediaFiles = Files()

    public init(config: Config) {
        config.register(self)
    }

    func checkOptions(publish: PublishStore) throws {
        publish.registerURLPathForMedia(self.urlPathForMedia)
        mediaFiles = mediaOpt.value.findMediaFileURLs()
    }

    private let MEDIA = "media"

    /// Unit test support
    var fakeMediaLookup = false

    /// Test for whether a filename matches a media file and return the url-path-component to link to it
    /// from the doc-root.  Used by Format during smart link resolution.
    func urlPathForMedia(filename: String) -> String? {
        if fakeMediaLookup { return "FAKE" }

        guard mediaFiles[filename] != nil else {
            return nil
        }
        return "\(MEDIA)/\(filename)" // how am I technically supposed to work with relative paths?
    }

    /// Populate a docset's media directory with the right files
    func copyMedia(docRoot: URL, languageTag: String) throws {
        logDebug("Media: Copying up files for \(languageTag)")
        guard !mediaFiles.isEmpty else {
            return
        }
        let mediaURL = docRoot.appendingPathComponent(MEDIA)
        try FileManager.default.createDirectory(at: mediaURL, withIntermediateDirectories: true)
        try mediaFiles.forEach { file in
            let destinationURL = mediaURL.appendingPathComponent(file.key)
            if let sourceURL = file.value[languageTag] {
                try FileManager.default.forceCopyItem(at: sourceURL, to: destinationURL)
            }
        }
    }
}

private extension Array where Element == Glob.Pattern {
    /// Interpret the globs and seek out localized files.
    /// Key of returned dictionary is the basename of the localized file, case preserved.
    /// We don't load the file -- we never do -- just remember their URLs.
    func findMediaFileURLs() -> GenMedia.Files {
        var files = [String: Localized<URL>]()
        forEach { globPattern in
            logDebug("Media: Searching for files using '\(globPattern)'")
            var count = 0
            Glob.files(globPattern).forEach { url in
                /// Need to be careful to not match the localization directories themselves
                guard !url.isFilesystemDirectory else {
                    return
                }
                let filename = url.lastPathComponent
                guard files[filename] == nil else {
                    logWarning(.wrnDuplicateGlobfile, filename, url.path)
                    return
                }
                files[filename] = Localized<URL>(localizingFile: url)
                count += 1
            }
            if count == 0 {
                logWarning(.wrnMediaMissing, globPattern)
            } else {
                logDebug("Media: Found \(count) files.")
            }
        }
        return files
    }
}
