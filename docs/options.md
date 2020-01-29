# Options

* [Syntax](#syntax) - how options work.
* [Gather](#gather) - getting information about declarations.
* [Generation](#gen) - output generation.
* [Meta](#meta) - how the program runs.

## Syntax

If an option is described as `--option-name` then it is a boolean flag and does
not have an associated value.  Its config key is `option_name` meaning you can
write `option_name: yes` (or `true` or `on`).  You can write `--no-option-name`
to invert the flag.

If an option is described as `--option-name VALUE` then it requires a single
value.  You can write `--option-name=VALUE`.  In the config file you can write
`option_name: value` or as a single-item sequence `option_name: [value]`.

If an option is described as `--option-name VALUE,...` then it requires 1+
values.  You can write `--option-name V1,V2,V3` using a backslash to escape an
actual comma, or repeat the option `--option-name V1 --option-name V2,V3`.  In
the config file you can write `option_name: V1` or a sequence.

CLI options don't have to be written in full, just enough to make the meaning
unambiguous.  Config files need you to write out the whole thing.

## Control

`--products` controls what the tool creates.  Lets you skip creation of parts
you don't need or generate structured json data describing various phases of
docs generation.  This can be used for ingestion elsewhere or as input to
another invocation of the program running on a different operating system, for
example.

* `file-json` prints file-oriented json describing the code declarations to be
documented.  See [xxx]().

## Gather
Two modes of operation, simple and custom.  _Simple_ is for one module (or
multiple modules in the same language & directory & compiler flags, such as
an app and its extensions). _Custom_ is for multiple modules built in multiple
ways in multiple locations -- configured only in the config file.

### Simple - Swift
* `--build-tool spm|xcodebuild` tool to build the module.  Guessed if omitted.
* `--build-tool-arguments` any extra flags to pass to the build tool.
* `--module` names of modules to build.  Guessed if omitted.
* `--source-directory PATH` where to build from.  Current dir if omitted.

## Gen
* `--output PATH` directory in which to put docs.
* `--clean` delete output directory and contents before starting.

## Meta
* `--config PATH` config file location.
* `--debug` debug mode.  Extra tracing with timestamps, all to stderr.
* `--help` show help and exit.
* `--quiet` quiet mode.  Print only fatal errors.
* `--version` show version and exit.
