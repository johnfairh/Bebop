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
    /// Unexpected YAML '%1' for key '%2', expected sequence.
    case errCfgNotSequence = "err-cfg-not-sequence"
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
    /// Couldn't create path enumerator starting '%1'.
    case errEnumerator = "err-enumerator"
    /// Missing key 'module' in a custom_modules stanza -- you have to set this.
    case errMissingModule = "err-missing-module"
    /// Both --module and custom_modules are set: choose just one.
    case errModulesOverlap = "err-modules-overlap"
    /// Both --objc-direct and --build-tool are set: choose just one.
    case errObjcBuildTools = "err-objc-build-tools"
    /// Documenting Objective-C modules is supported only on macOS.
    case errObjcLinux = "err-objc-linux"
    /// Some Objective-C options are set but --objc-header-file is not.
    case errObjcNoHeader = "err-objc-no-header"
    /// Couldn't find SDK path.
    case errObjcSdk = "err-objc-sdk"
    /// Unexpected data shape from SourceKitten json, can't process dict '%1'.
    case errObjcSourcekitten = "err-objc-sourcekitten"
    /// Path is for a regular file, not a directory: '%1'.
    case errPathNotDir = "err-path-not-dir"
    /// Path doesn't exist or is inaccessible: '%1'.
    case errPathNotExist = "err-path-not-exist"
    /// Path is for a directory, not a regular file: '%1'.
    case errPathNotFile = "err-path-not-file"
    /// Module name '%1' repeated in --modules.
    case errRepeatedModule = "err-repeated-module"
    /// SourceKitten couldn't find build info from `swift build`.  Check the log mentioned above.
    case errSktnSpm = "err-sktn-spm"
    /// SourceKitten couldn't find build info from `xcodebuild`.  Check the log mentioned above; it was looking for a `swiftc` command that included `-module-name`.
    case errSktnXcodeDef = "err-sktn-xcode-def"
    /// SourceKitten couldn't find build info from `xcodebuild`.  Check the log above; it was looking for a `swiftc` command that included `-module-name %1`.
    case errSktnXcodeMod = "err-sktn-xcode-mod"
    /// Using config file '%1'.
    case msgConfigFile = "msg-config-file"
    /// %1% documentation coverage with %2 undocumented symbols.
    case msgCoverage = "msg-coverage"
    /// Gathering info for %1.
    case msgGatherHeading = "msg-gather-heading"
    /// Generating documentation
    case msgGeneratingDocs = "msg-generating-docs"
    /// j2: Generate API documentation for Swift or Objective-C code.\n\nUsage: j2 [options]\n\nOptions:
    case msgHelpIntro = "msg-help-intro"
    /// Skipped %1 %2 symbols.
    case msgSwiftAcl = "msg-swift-acl"
    /// No definitions found in --default-langauge '%1', using '%2' instead.
    case wrnBadUserLanguage = "wrn-bad-user-language"
    /// Config key '%1' ignored, already set on command-line.
    case wrnCfgIgnored = "wrn-cfg-ignored"
    /// Language tags missing for '%1': %2.
    case wrnCfgLanguageMissing = "wrn-cfg-language-missing"
    /// Duplicate guide name '%1', ignoring '%2'.
    case wrnDuplicateGuide = "wrn-duplicate-guide"
    /// No guides matching '*.md' found expanding '%1'.
    case wrnEmptyGuideGlob = "wrn-empty-guide-glob"
    /// Swift compiler error for '%1' %2, ignoring.  Check build flags and import statements?
    case wrnErrorType = "wrn-error-type"
    /// fnmatch(3) failed, pattern '%1', path '%2', errno %3/%4.
    case wrnFnmatchErrno = "wrn-fnmatch-errno"
    /// glob(3) failed, pattern '%1', errno %2/%3.
    case wrnGlobErrno = "wrn-glob-errno"
    /// glob(3) error with paths for pattern '%1'.
    case wrnGlobPattern = "wrn-glob-pattern"
    /// Bad file json data for '%1' pass %2: missing 'key.diagnostic_stage' key.  Ignoring this file.
    case wrnMergeMissingRoot = "wrn-merge-missing-root"
    /// Doc comments will not be localized because --doc-comment-languages-directory is not set.
    case wrnNoCommentLanguages = "wrn-no-comment-languages"
    /// Doc comments will not be localized for '%1' because cannot open '%2'.
    case wrnNoCommentMissing = "wrn-no-comment-missing"
    /// Objective-C direct mode requested but --module is not set: using 'Module' for the module name.
    case wrnObjcModule = "wrn-objc-module"
    /// Cannot chdir back to '%1'.
    case wrnPathNoChdir = "wrn-path-no-chdir"
    /// --quiet and --debug both set, ignoring --quiet.
    case wrnQuietDebug = "wrn-quiet-debug"
    /// Incomplete definition JSON '%1' %2, ignoring.
    case wrnSktnIncomplete = "wrn-sktn-incomplete"
    /// Unsupported definition kind '%1', ignoring.
    case wrnSktnKind = "wrn-sktn-kind"
    /// Confused by different types sharing a USR.\n1: %1\n2: %2\nIgnoring the second.
    case wrnUsrCollision = "wrn-usr-collision"
  }
  internal enum Output : String {
    /// Authors
    case authors = "authors"
    /// Available where %1
    case availableWhere = "available-where"
    /// …where %1
    case availableWhereShort = "available-where-short"
    /// Categories
    case categories = "categories"
    /// &copy; %1%2. All rights reserved. (Last updated: %3).
    case copyright = "copyright"
    /// Declaration
    case declaration = "declaration"
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
    /// Provided by module `%1`.
    case imported = "imported"
    /// Index
    case index = "index"
    /// Not available in Objective-C.
    case notObjc = "not-objc"
    /// Not available in Swift.
    case notSwift = "not-swift"
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
    /// Has a default implementation.
    case protocolDefault = "protocol-default"
    /// Default implementation only for types that satisfy the constraints.
    case protocolDefaultConditional = "protocol-default-conditional"
    /// Has a default implementation for some conforming types.
    case protocolDefaultConditionalExists = "protocol-default-conditional-exists"
    /// Has a default implementation provided by module `%1`.
    case protocolDefaultImported = "protocol-default-imported"
    /// From a protocol extension: not a customization point.
    case protocolExtn = "protocol-extn"
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
