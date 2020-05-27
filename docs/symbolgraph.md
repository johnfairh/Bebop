# Swift SymbolGraph

The `swift symbolgraph` command is new in Swift 5.3 and extracts information
from a pre-built `.swiftmodule` suitable for docs.  Bebop can wrap this up using
the `--build-tool swift-symbolgraph` mode, see [options](options.md) for more.

The tool is new and has various bugs and problems - at time of writing
(early April 2020, Swift 5.3 master) using the from-source options will always
give you at least as good results, usually better.

## Bug list

* Doc comments - can’t tell whether from code or inherited
* Location - missing for non-public decls
* DocComments - missing for non-public decls, missing for extensions
* DocComments - lost from proto req default impls
* ~Readonly properties/subscripts broken, no { get / set } even in protocols~
* public private(set) var broken, setter ignored / ~no { get }~
* Typealiases for proto composition not respected (Codable)
* Crashes horribly if anything slightly wrong with sourceinfo.
  No x-checks between module artefacts.
* static/class decl kinds conflated
* Too many Selfs in declprinter
* Omitted enum ~and function~ param labels
* Unwanted subscript param labels
* Override relation - only for class members, nothing for protocol witness
* Implementation protocol Self conformance _sometimes_ exposed
* swiftExtension / swiftGenerics is messy, func is own generic context; Apr16
we now get _both at once_ repeating constraints...
* No fallback name on conformsTo source, “ext String : P {}” 
* Weird tramp constraints “extension Dictionary : P” gets Element: Hashable
* `defaultImplementation` relation pretty broken in Apr16, no `memberOf`
  so cannot understand what type the impl is provided as part of.
