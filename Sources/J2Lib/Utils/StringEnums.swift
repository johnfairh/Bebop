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
    /// Module merging is disabled for '%1' but `merge_module_group` is set.
    case errCfgBadModMerge = "err-cfg-bad-mod-merge"
    /// Could not recognize absolute URL: '%1'.
    case errCfgBadUrl = "err-cfg-bad-url"
    /// Config key 'custom_brand.image_name' of '%1' did not match any file from --media.
    case errCfgBrandBadImage = "err-cfg-brand-bad-image"
    /// Config key 'image_name' not set under 'custom_brand'.
    case errCfgBrandMissingImage = "err-cfg-brand-missing-image"
    /// Config key 'custom_code_host.image_name' of '%1' did not match any file from --media.
    case errCfgChostBadImage = "err-cfg-chost-bad-image"
    /// Both --code-host and config key 'custom_code_host' are set: choose just one.
    case errCfgChostBoth = "err-cfg-chost-both"
    /// One of the custom code-host line format keys is missing: you must supply both or neither of 'single_line_format' and 'multi_line_format'.
    case errCfgChostMissingFmt = "err-cfg-chost-missing-fmt"
    /// Config key 'image_name' not set under 'custom_code_host'.
    case errCfgChostMissingImage = "err-cfg-chost-missing-image"
    /// Config key 'custom_code_host.multi_line_format' does not contain both '%1' and '%2'.
    case errCfgChostMultiFmt = "err-cfg-chost-multi-fmt"
    /// Config key 'custom_code_host.single_line_format' does not contain '%1'.
    case errCfgChostSingleFmt = "err-cfg-chost-single-fmt"
    /// Custom def missing 'name' config key: '%1'.
    case errCfgCustomDefName = "err-cfg-custom-def-name"
    /// Custom def topic missing 'name' config key: '%1'.
    case errCfgCustomDefTopicName = "err-cfg-custom-def-topic-name"
    /// Custom def missing 'topics' config key: '%1'.
    case errCfgCustomDefTopics = "err-cfg-custom-def-topics"
    /// Custom group/topic has both 'children' and 'topics' config keys: '%1'.
    case errCfgCustomGrpBoth = "err-cfg-custom-grp-both"
    /// Custom group/topic missing 'name' config key: '%1'.
    case errCfgCustomGrpName = "err-cfg-custom-grp-name"
    /// Custom topic has nested 'topics' config key: '%1'.
    case errCfgCustomGrpNested = "err-cfg-custom-grp-nested"
    /// Custom group has 'skip_unlisted' config key without 'topics': '%1'.
    case errCfgCustomGrpUnlisted = "err-cfg-custom-grp-unlisted"
    /// Docset icons must be in .png format.  '%1' has the wrong file extension.
    case errCfgDocsetIcon = "err-cfg-docset-icon"
    /// Module merge policy is set both outside and inside `custom_modules`: choose just one.
    case errCfgDupModMerge = "err-cfg-dup-mod-merge"
    /// Missing field from guide_title entry, must have both 'name' and 'title': '%1'.
    case errCfgGuideTitleFields = "err-cfg-guide-title-fields"
    /// Both --j2-json-files and other data-source options are set: choose just one.
    case errCfgJ2jsonMutex = "err-cfg-j2json-mutex"
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
    /// Could not interpret file contents as YAML: '%1'.
    case errCfgNotYaml = "err-cfg-not-yaml"
    /// Both --podspec and some other build-source option are set: choose just one.
    case errCfgPodspecBuild = "err-cfg-podspec-build"
    /// The --podspec option can't be set alongside the 'custom_modules' config key or with multi-valued --modules.
    case errCfgPodspecOuter = "err-cfg-podspec-outer"
    /// The --podspec option can't be set at the 'module pass' level because it generates multiple passes.
    case errCfgPodspecPass = "err-cfg-podspec-pass"
    /// Invalid ICU regular expression '%1'.  Original error: '%2'.
    case errCfgRegexp = "err-cfg-regexp"
    /// Both --sourcekitten-sourcefiles and some Swift or Objective-C flags are set: choose just one.
    case errCfgSknBuildTool = "err-cfg-skn-build-tool"
    /// Both --sourcekitten-sourcefiles and custom_modules are set: choose just one.
    case errCfgSknCustomModules = "err-cfg-skn-custom-modules"
    /// Can't use --sourcekitten-sourcefiles with multivalued --modules.
    case errCfgSknMultiModules = "err-cfg-skn-multi-modules"
    /// Can't set '%1' as part of custom `swift symbolgraph` arguments.
    case errCfgSsgeArgs = "err-cfg-ssge-args"
    /// Running `swift symbolgraph-extract` failed.  Report:\n%1
    case errCfgSsgeExec = "err-cfg-ssge-exec"
    /// Running `swift symbolgraph-extract` didn't create a main symbols file.
    case errCfgSsgeMainMissing = "err-cfg-ssge-main-missing"
    /// Must set a module name to use --build-tool=swift-symbolgraph.
    case errCfgSsgeModule = "err-cfg-ssge-module"
    /// Value for --swift-symbolgraph-target does not like an LLVM target triple: '%1'
    case errCfgSsgeTriple = "err-cfg-ssge-triple"
    /// Unexpected text '%1' for config key '%2', expected boolean.
    case errCfgTextNotBool = "err-cfg-text-not-bool"
    /// Can't use 'theme' along with any other value in --products.
    case errCfgThemeCopy = "err-cfg-theme-copy"
    /// Value for --apple-autolink-xcode-path should be some Xcode.app, not '%1'.
    case errCfgXcodepath = "err-cfg-xcodepath"
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
    /// Can't decode JSON as Swift type '%1': %2.
    case errJsonDecode = "err-json-decode"
    /// Missing key 'module' in a custom_modules stanza -- you have to set this.
    case errMissingModule = "err-missing-module"
    /// Both --module and custom_modules are set: choose just one.
    case errModulesOverlap = "err-modules-overlap"
    /// Not implemented: %1.
    case errNotImplemented = "err-not-implemented"
    /// Both --objc-direct and --build-tool are set: choose just one.
    case errObjcBuildTools = "err-objc-build-tools"
    /// Documenting Objective-C modules is supported only on macOS.
    case errObjcLinux = "err-objc-linux"
    /// Some Objective-C options are set but --objc-header-file is not.
    case errObjcNoHeader = "err-objc-no-header"
    /// Unexpected data shape from SourceKitten JSON, can't process dict '%1'.
    case errObjcSourcekitten = "err-objc-sourcekitten"
    /// Path is for a regular file, not a directory: '%1'.
    case errPathNotDir = "err-path-not-dir"
    /// Path doesn't exist or is inaccessible: '%1'.
    case errPathNotExist = "err-path-not-exist"
    /// Path is for a directory, not a regular file: '%1'.
    case errPathNotFile = "err-path-not-file"
    /// Can't unpack podspec:\n%1
    case errPodspecFailed = "err-podspec-failed"
    /// Module name mismatch: expected '%1', podspec defines '%2'.
    case errPodspecModulename = "err-podspec-modulename"
    /// Module name '%1' repeated in --modules.
    case errRepeatedModule = "err-repeated-module"
    /// Sass compile failed, rc=%1: %2.
    case errSassCompile = "err-sass-compile"
    /// Couldn't find SDK path.\n
    case errSdk = "err-sdk"
    /// SourceKitten couldn't find build info from `swift build`.  Check the log mentioned above.
    case errSktnSpm = "err-sktn-spm"
    /// SourceKitten couldn't find build info from `xcodebuild`.  Check the log mentioned above; it was looking for a `swiftc` command that included `-module-name`.
    case errSktnXcodeDef = "err-sktn-xcode-def"
    /// SourceKitten couldn't find build info from `xcodebuild`.  Check the log above; it was looking for a `swiftc` command that included `-module-name %1`.
    case errSktnXcodeMod = "err-sktn-xcode-mod"
    /// Theme localized key clash with content keys, values: '%1' '%2'.
    case errThemeKeyClash = "err-theme-key-clash"
    /// Couldn't fetch URL '%1'.\nResponse: %2\nError: %3
    case errUrlFetch = "err-url-fetch"
    /// XMLParser failed: '%1', line '%1' column '%2'.
    case errXmlDocsParse = "err-xml-docs-parse"
    /// Documentation complete in %1
    case msgComplete = "msg-complete"
    /// Using config file '%1'
    case msgConfigFile = "msg-config-file"
    /// Copying theme files
    case msgCopyingTheme = "msg-copying-theme"
    /// %1% documentation coverage with %2 documented and %3 undocumented definitions
    case msgCoverage = "msg-coverage"
    /// Generating %1
    case msgDocsetProgress = "msg-docset-progress"
    /// Gathering info for %1
    case msgGatherHeading = "msg-gather-heading"
    /// Generating documentation
    case msgGeneratingDocs = "msg-generating-docs"
    /// Option aliases for Jazzy compatibility:
    case msgHelpAliases = "msg-help-aliases"
    /// j2: Generate API documentation for Swift or Objective-C code.\n\nUsage: j2 [options]\n\nOptions:
    case msgHelpIntro = "msg-help-intro"
    /// Rendering theme in classic Jazzy mode
    case msgJazzyTheme = "msg-jazzy-theme"
    /// Skipped %1 %2 definitions
    case msgSwiftAcl = "msg-swift-acl"
    /// Unpacking podspec %1
    case msgUnpackPodspec = "msg-unpack-podspec"
    /// Can't open Apple documentation database '%1': %2
    case wrnAppleautoDbo = "wrn-appleauto-dbo"
    /// Can't query Apple documentation database for '%1': %2
    case wrnAppleautoDbq = "wrn-appleauto-dbq"
    /// Can't find current Xcode path, not linking to Apple documentation.\n%1;
    case wrnAppleautoXcode = "wrn-appleauto-xcode"
    /// No definitions found in --default-language '%1', using '%2' instead.
    case wrnBadUserLanguage = "wrn-bad-user-language"
    /// Config key '%1' ignored, already set on command-line.
    case wrnCfgIgnored = "wrn-cfg-ignored"
    /// Language tags missing for '%1': %2.
    case wrnCfgLanguageMissing = "wrn-cfg-language-missing"
    /// Duplicate 'custom_defs' entry for '%1', using only the first one seen.
    case wrnCustomDefDup = "wrn-custom-def-dup"
    /// Can't resolve 'custom_defs' child '%1' inside '%2'.
    case wrnCustomDefMissing = "wrn-custom-def-missing"
    /// Can't resolve item name '%1' inside 'custom_groups', ignoring.
    case wrnCustomGrpMissing = "wrn-custom-grp-missing"
    /// The --docset-path option is ignored: the docset is created under '<output>/docsets'.
    case wrnDocsetPath = "wrn-docset-path"
    /// Can't create docset tarfile.\n%1
    case wrnDocsetTarfile = "wrn-docset-tarfile"
    /// Duplicate filename '%1', ignoring '%2'.
    case wrnDuplicateGlobfile = "wrn-duplicate-globfile"
    /// No files matching '*.md' found expanding '%1'.
    case wrnEmptyGlob = "wrn-empty-glob"
    /// Swift compiler error for '%1' %2, ignoring.  Check build flags and import statements?
    case wrnErrorType = "wrn-error-type"
    /// fnmatch(3) failed, pattern '%1', path '%2', errno %3/%4.
    case wrnFnmatchErrno = "wrn-fnmatch-errno"
    /// glob(3) failed, pattern '%1', errno %2/%3.
    case wrnGlobErrno = "wrn-glob-errno"
    /// glob(3) error with paths for pattern '%1'.
    case wrnGlobPattern = "wrn-glob-pattern"
    /// Found custom abstract for guide '%1', ignoring.  Add content directly to the guide.
    case wrnGuideAbstract = "wrn-guide-abstract"
    /// Duplicate 'guide_titles' entries for '%1', using the first one seen.
    case wrnGuideTitleDup = "wrn-guide-title-dup"
    /// Some 'guide_titles' entries did not match any guides: %1.
    case wrnGuideTitleUnused = "wrn-guide-title-unused"
    /// Can't decode J2 JSON portion from '%1': %2.
    case wrnJ2jsonDecode = "wrn-j2json-decode"
    /// Can't import J2 JSON file '%1', version '%2' is from a later version of the program.
    case wrnJ2jsonFuture = "wrn-j2json-future"
    /// No media files found matching '%1'.
    case wrnMediaMissing = "wrn-media-missing"
    /// Bad file JSON data for '%1' pass %2: missing 'key.diagnostic_stage' key.  Ignoring this file.
    case wrnMergeMissingRoot = "wrn-merge-missing-root"
    /// Doc comments will not be localized for '%1' because cannot open '%2'.
    case wrnNoCommentMissing = "wrn-no-comment-missing"
    /// Objective-C direct mode requested but --modules is not set: using 'Module' for the module name.
    case wrnObjcModule = "wrn-objc-module"
    /// Cannot chdir back to '%1'.
    case wrnPathNoChdir = "wrn-path-no-chdir"
    /// --quiet and --debug both set, ignoring --quiet.
    case wrnQuietDebug = "wrn-quiet-debug"
    /// Can't decode SourceKitten JSON portion from '%1': %2.
    case wrnSknDecode = "wrn-skn-decode"
    /// SourceKitten import mode requested but --modules is not set: using 'Module' for the module name.
    case wrnSknModuleName = "wrn-skn-module-name"
    /// Incomplete definition JSON '%1' %2, ignoring.
    case wrnSktnIncomplete = "wrn-sktn-incomplete"
    /// Unsupported definition kind '%1', ignoring.
    case wrnSktnKind = "wrn-sktn-kind"
    /// Undecodable swift-symbolgraph availability, missing both 'domain' and 'isUnconditionallyDeprecated'.
    case wrnSsgeAvailability = "wrn-ssge-availability"
    /// Can't figure out the type to which default protocol requirement '%1' belongs, ignoring.
    case wrnSsgeBadDefaultReq = "wrn-ssge-bad-default-req"
    /// Can't resolve source USR '%1' for relationship kind '%2', ignoring.
    case wrnSsgeBadSrcUsr = "wrn-ssge-bad-src-usr"
    /// Unknown swift-symbolgraph constraint kind '%1', ignoring.
    case wrnSsgeConstKind = "wrn-ssge-const-kind"
    /// Confused by `swift symbolgraph-extract` output filename '%1', ignoring.
    case wrnSsgeOddFilename = "wrn-ssge-odd-filename"
    /// Unknown swift-symbolgraph relationship kind '%1', ignoring.
    case wrnSsgeRelKind = "wrn-ssge-rel-kind"
    /// Unknown swift-symbolgraph access level '%1', ignoring.
    case wrnSsgeSymbolAcl = "wrn-ssge-symbol-acl"
    /// Unknown swift-symbolgraph symbol kind '%1', ignoring.
    case wrnSsgeSymbolKind = "wrn-ssge-symbol-kind"
    /// Can't figure out host target triple, using default '%1'
    case wrnSsgeTriple = "wrn-ssge-triple"
    /// Can't find Objective-C header file for module '%1' at '%2'.
    case wrnSw2objcHeader = "wrn-sw2objc-header"
    /// Unrecognized accessibility '%1' for '%2', using 'internal'.
    case wrnUnknownAcl = "wrn-unknown-acl"
    /// %1 unmatched custom abstracts: '%2'.
    case wrnUnmatchedAbstracts = "wrn-unmatched-abstracts"
    /// Custom group regular expression '/%1/' did not match any items.
    case wrnUnmatchedGrpRegex = "wrn-unmatched-grp-regex"
    /// Confused by different types sharing a USR.\n1: %1\n2: %2\nIgnoring the second.
    case wrnUsrCollision = "wrn-usr-collision"
    /// Couldn't parse XML doc comment '%1': %2
    case wrnXmlDocsParse = "wrn-xml-docs-parse"
  }
  internal enum Output : String {
    /// Authors
    case authors = "authors"
    /// Available %1
    case availableWhere = "available-where"
    /// …%1
    case availableWhereShort = "available-where-short"
    /// Categories
    case categories = "categories"
    /// %1 Categories
    case categoriesCustom = "categories-custom"
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
    /// %1 Extensions
    case extensionsCustom = "extensions-custom"
    /// Functions
    case functions = "functions"
    /// %1 Functions
    case functionsCustom = "functions-custom"
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
    /// Operators
    case operators = "operators"
    /// %1 Operators
    case operatorsCustom = "operators-custom"
    /// Others
    case others = "others"
    /// %1 Others
    case othersCustom = "others-custom"
    /// %1 - deprecated.
    case platDeprecated = "plat-deprecated"
    /// %1 - deprecated since %2.
    case platDeprecatedVer = "plat-deprecated-ver"
    /// %1 - obsoleted since %2.
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
    ///  Renamed to `%1`.
    case renamedTo = "renamed-to"
    /// Show on BitBucket
    case showOnBitBucket = "show-on-bit-bucket"
    /// Show on GitHub
    case showOnGitHub = "show-on-git-hub"
    /// Show on GitLab
    case showOnGitLab = "show-on-git-lab"
    /// Associated Types
    case tpcAssociatedTypes = "tpc-associated-types"
    /// Class Methods
    case tpcClassMethods = "tpc-class-methods"
    /// Class Properties
    case tpcClassProperties = "tpc-class-properties"
    /// Class Subscripts
    case tpcClassSubscripts = "tpc-class-subscripts"
    /// Deinitializer
    case tpcDeinitializer = "tpc-deinitializer"
    /// Cases
    case tpcEnumElements = "tpc-enum-elements"
    /// Fields
    case tpcFields = "tpc-fields"
    /// Initializers
    case tpcInitializers = "tpc-initializers"
    /// Methods
    case tpcMethods = "tpc-methods"
    /// Operators
    case tpcOperators = "tpc-operators"
    /// Other Members
    case tpcOthers = "tpc-others"
    /// Properties
    case tpcProperties = "tpc-properties"
    /// Static Methods
    case tpcStaticMethods = "tpc-static-methods"
    /// Static Properties
    case tpcStaticProperties = "tpc-static-properties"
    /// Static Subscripts
    case tpcStaticSubscripts = "tpc-static-subscripts"
    /// Subscripts
    case tpcSubscripts = "tpc-subscripts"
    /// Types
    case tpcTypes = "tpc-types"
    /// Types
    case types = "types"
    /// %1 Types
    case typesCustom = "types-custom"
    /// Unavailable.
    case unavailable = "unavailable"
    /// Variables
    case variables = "variables"
    /// %1 Variables
    case variablesCustom = "variables-custom"
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name
