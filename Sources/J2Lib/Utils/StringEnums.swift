// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name
internal enum L10n {
  internal enum Localizable : String {
    /// Unrecognized config key '%1'.
    case errCfgBadKey = "err-cfg-bad-key"
    /// Unexpected config shape, found mapping for key '%1'.
    case errCfgBadMapping = "err-cfg-bad-mapping"
    /// Unexpected multiple values '%1' for config key '%2', expecting just one.
    case errCfgMultiSeq = "err-cfg-multi-seq"
    /// Unexpected YAML, mapping key is '%1', expected scalar.
    case errCfgNonScalarKey = "err-cfg-non-scalar-key"
    /// Unexpected YAML '%1' for key '%2', expected mapping.
    case errCfgNotMapping = "err-cfg-not-mapping"
    /// Unexpected YAML '%1' for key '%2', expected scalar.
    case errCfgNotScalar = "err-cfg-not-scalar"
    /// Could not interpret config file as YAML.
    case errCfgNotYaml = "err-cfg-not-yaml"
    /// Unexpected text '%1' for config key '%2', expected boolean.
    case errCfgTextNotBool = "err-cfg-text-not-bool"
    /// Missing argument for option '%1'.
    case errCliMissingArg = "err-cli-missing-arg"
    /// Unexpected repeated option '%1'.
    case errCliRepeated = "err-cli-repeated"
    /// Unexpected text '%1'.
    case errCliUnexpected = "err-cli-unexpected"
    /// Unknown option '%1'.
    case errCliUnknownOption = "err-cli-unknown-option"
    /// Invalid value '%1' for '%2', valid values: '%3'.
    case errEnumValue = "err-enum-value"
    /// Path is for a regular file, not a directory: '%1'.
    case errPathNotDir = "err-path-not-dir"
    /// Path doesn't exist or is inaccessible: '%1'.
    case errPathNotExist = "err-path-not-exist"
    /// Path is for a directory, not a regular file: '%1'.
    case errPathNotFile = "err-path-not-file"
    /// SourceKitten couldn't find build info from `swift build`.  Check the log mentioned above.
    case errSktnSpm = "err-sktn-spm"
    /// SourceKitten couldn't find build info from `xcodebuild`.  Check the log mentioned above; it was looking for a `swiftc` command that included `-module-name`.
    case errSktnXcodeDef = "err-sktn-xcode-def"
    /// SourceKitten couldn't find build info from `xcodebuild`.  Check the log above; it was looking for a `swiftc` command that included `-module-name %1`.
    case errSktnXcodeMod = "err-sktn-xcode-mod"
    /// Using config file '%1'.
    case msgConfigFile = "msg-config-file"
    /// Generating documentation
    case msgGeneratingDocs = "msg-generating-docs"
    /// j2: Generate API documentation for Swift or Objective-C code.\n\nUsage: j2 [options]\n\nOptions:
    case msgHelpIntro = "msg-help-intro"
    /// Config key '%1' ignored, already set on command-line.
    case wrnCfgIgnored = "wrn-cfg-ignored"
    /// Language tags missing for '%1': %2.
    case wrnCfgLanguageMissing = "wrn-cfg-language-missing"
    /// Duplicate guide name '%1', ignoring '%2'.
    case wrnDuplicateGuide = "wrn-duplicate-guide"
    /// No guides matching '*.md' found expanding '%1'.
    case wrnEmptyGuideGlob = "wrn-empty-guide-glob"
    /// fnmatch(3) failed, pattern '%1', path '%2', errno %3/%4.
    case wrnFnmatchErrno = "wrn-fnmatch-errno"
    /// glob(3) failed, pattern '%1', errno %2/%3.
    case wrnGlobErrno = "wrn-glob-errno"
    /// glob(3) error with paths for pattern '%1'.
    case wrnGlobPattern = "wrn-glob-pattern"
    /// Bad file json data for '%1' pass %2: missing 'key.diagnostic_stage' key.  Ignoring this file.
    case wrnMergeMissingRoot = "wrn-merge-missing-root"
    /// Doc comments will not be localized because '--doc-comment-languages-directory' is not set.
    case wrnNoCommentLanguages = "wrn-no-comment-languages"
    /// Doc comments will not be localized for '%1' because cannot open '%2'.
    case wrnNoCommentMissing = "wrn-no-comment-missing"
    /// Cannot chdir back to '%1'.
    case wrnPathNoChdir = "wrn-path-no-chdir"
    /// --quiet and --debug both set, ignoring --quiet.
    case wrnQuietDebug = "wrn-quiet-debug"
  }
  internal enum Output : String {
    /// Deprecated.
    case deprecated = "deprecated"
    /// docs
    case docs = "docs"
    /// Extensions
    case extensions = "extensions"
    /// Functions
    case functions = "functions"
    /// Guides
    case guides = "guides"
    /// Index
    case index = "index"
    /// Others
    case others = "others"
    /// %1 - deprecated.
    case platDeprecated = "plat-deprecated"
    /// %1 - deprecated in %2.
    case platDeprecatedVer = "plat-deprecated-ver"
    /// %1 - obsoleted in %2.
    case platObsoletedVer = "plat-obsoleted-ver"
    /// %1 - unavailable.
    case platUnavailable = "plat-unavailable"
    ///  Renamed: `%1`.
    case renamedTo = "renamed-to"
    /// Types
    case types = "types"
    /// Unavailable.
    case unavailable = "unavailable"
    /// Variables
    case variables = "variables"
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name
