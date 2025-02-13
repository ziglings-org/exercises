# Ziglings

Welcome to Ziglings! This project contains a series of tiny
broken programs (and one nasty surprise).  By fixing them, you'll
learn how to read and write [Zig](https://ziglang.org/) code.

![Ziglings](images/ziglings.jpg "Ziglings")

Those broken programs need your help! (You'll also save the
planet from evil aliens and help some friendly elephants stick
together, which is very sweet of you.)

This project was initiated by [Dave Gauer](https://ratfactor.com/) and is directly inspired
by the brilliant and fun [rustlings](https://github.com/rust-lang/rustlings) project.
Indirect inspiration comes from [Ruby Koans](http://rubykoans.com/) and the Little LISPer/Little
Schemer series of books.

## Intended Audience

This will probably be difficult if you've _never_ programmed
before.  But no specific programming experience is required. And
in particular, you are _not_ expected to have any prior
experience with "systems programming" or a "systems" level
language such as C.

Each exercise is self-contained and self-explained. However,
you're encouraged to also check out these Zig language resources
for more detail:

* https://ziglang.org/learn/
* https://ziglearn.org/
* https://ziglang.org/documentation/master/
* [Zig in Depth! (video series)](https://www.youtube.com/watch?v=MMtvGA1YhW4&list=PLtB7CL7EG7pCw7Xy1SQC53Gl8pI7aDg9t&pp=iAQB)

Also, the [Zig community](https://github.com/ziglang/zig/wiki/Community)
is incredibly friendly and helpful!

## Getting Started

Install a [development build](https://ziglang.org/download/) of
the Zig compiler.  (See the "master" section of the downloads
page.)

Verify the installation and build number of `zig` like so:

```
$ zig version
0.14.0-dev.xxxx+xxxxxxxxx
```

Clone this repository with Git:

```
git clone https://codeberg.org/ziglings/exercises.git ziglings
cd ziglings
```

Then run `zig build` and follow the instructions to begin!

```
zig build
```

Note: The output of Ziglings is the unaltered output from the Zig
compiler. Part of the purpose of Ziglings is to acclimate you to
reading these.

## A Note About Versions

**Hint:** To check out Ziglings for a stable release of Zig, you can use
the appropriate tag.

The Zig language is under very active development. In order to be
current, Ziglings tracks **development** builds of the Zig
compiler rather than versioned **release** builds. The last
stable release was `0.13.0`, but Ziglings needs a dev build with
pre-release version "0.14.0" and a build number at least as high
as that shown in the example version check above.

It is likely that you'll download a build which is _greater_ than
the minimum.

Once you have a build of the Zig compiler that works with
Ziglings, they'll continue to work together. But keep in mind
that if you update one, you may need to also update the other.


### Version Changes

Version-0.14.0-dev.1573
* *2024-09-16* zig 0.14.0-dev.1573 - introduction of labeled switch, see [#21257](https://github.com/ziglang/zig/pull/21257)
* *2024-09-02* zig 0.14.0-dev.1409 - several changes in std.builtin, see [#21225](https://github.com/ziglang/zig/pull/21225)
* *2024-08-04* zig 0.14.0-dev.1224 - several changes in build system, see [#21115](https://github.com/ziglang/zig/pull/21115)
* *2024-08-04* zig 0.14.0-dev.839 - several changes in build system, see [#20580](https://github.com/ziglang/zig/pull/20580), [#20600](https://github.com/ziglang/zig/issues/20600)
* *2024-06-17* zig 0.14.0-dev.42 - changes in `std.mem.split and tokenize` - see [#15579](https://github.com/ziglang/zig/pull/15579)
* *2024-05-29* zig 0.13.0-dev.339 - rework std.Progress - see [#20059](https://github.com/ziglang/zig/pull/20059)
* *2024-03-21* zig 0.12.0-dev.3518 - change to @fieldParentPtr - see [#19470](https://github.com/ziglang/zig/pull/19470)
* *2024-03-21* zig 0.12.0-dev.3397 - rename std.os to std.posix - see [#5019](https://github.com/ziglang/zig/issues/5019)
* *2024-03-14* zig 0.12.0-dev.3302 - changes in `std.fmt` - floating-point formatting implementation - see [#19229](https://github.com/ziglang/zig/pull/19229)
* *2024-02-05* zig 0.12.0-dev.2618 - changes in `build system` - from `Step.zig_exe` to `Step.graph.zig_exe` - see [#18778](https://github.com/ziglang/zig/issues/18778)
* *2024-01-05* zig 0.12.0-dev.2043 - rename of `std.Build.FileSource` to `std.Build.LazyPath` - see [#16353](https://github.com/ziglang/zig/issues/16353)
* *2023-10-24* zig 0.12.0-dev.1243 - changes in `std.ChildProcess`: renamed exec to run - see [#5853](https://github.com/ziglang/zig/issues/5853)
* *2023-06-26* zig 0.11.0-dev.4246 - changes in compile step (now it can be null)
* *2023-06-26* zig 0.11.0-dev.3853 - removal of destination type from all cast builtins
* *2023-06-20* zig 0.11.0-dev.3747 - `@enumToInt` is now `@intFromEnum` and `@intToFloat` is now `@floatFromInt`
* *2023-05-25* zig 0.11.0-dev.3295 - `std.debug.TTY` is now `std.io.tty`
* *2023-04-30* zig 0.11.0-dev.2704 - use of the new `std.Build.ExecutableOptions.link_libc` field
* *2023-04-12* zig 0.11.0-dev.2560 - changes in `std.Build` - remove run() and install()
* *2023-04-07* zig 0.11.0-dev.2401 - fixes of the new build system - see [#212](https://github.com/ratfactor/ziglings/pull/212)
* *2023-02-21* zig 0.11.0-dev.2157 - changes in `build system` - new: parallel processing of the build steps
* *2023-02-21* zig 0.11.0-dev.1711 - changes in `for loops` - new: Multi-Object For-Loops + Struct-of-Arrays
* *2023-02-12* zig 0.11.0-dev.1638 - changes in `std.Build` cache_root now returns a directory struct
* *2023-02-04* zig 0.11.0-dev.1568 - changes in `std.Build` (combine `std.build` and `std.build.Builder` into `std.Build`)
* *2023-01-14* zig 0.11.0-dev.1302 - changes in `@addWithOverflow` (now returns a tuple) and `@typeInfo`; temporary disabled async functionality
* *2022-09-09* zig 0.10.0-dev.3978 - change in `NativeTargetInfo.detect` in build
* *2022-09-06* zig 0.10.0-dev.3880 - Ex 074 correctly fails again: comptime array len
* *2022-08-29* zig 0.10.0-dev.3685 - `@typeName()` output change, stage1 req. for async
* *2022-07-31* zig 0.10.0-dev.3385 - std lib string `fmt()` option changes
* *2022-03-19* zig 0.10.0-dev.1427 - method for getting sentinel of type changed
* *2021-12-20* zig 0.9.0-dev.2025 - `c_void` is now `anyopaque`
* *2021-06-14* zig 0.9.0-dev.137  - std.build.Id `.Custom` is now `.custom`
* *2021-04-21* zig 0.8.0-dev.1983 - std.fmt.format() `any` format string required
* *2021-02-12* zig 0.8.0-dev.1065 - std.fmt.format() `s` (string) format string required

## Advanced Usage

It can be handy to check just a single exercise:

```
zig build -Dn=19
```

Or run all exercises, starting from a specific one:

```
zig build -Ds=27
```

Or let Ziglings pick an exercise for you:

```
zig build -Drandom
```

You can also run without checking for correctness:

```
zig build -Dn=19 test
```

Or skip the build system entirely and interact directly with the
compiler if you're into that sort of thing:

```
zig run exercises/001_hello.zig
```

Calling all wizards: To prepare an executable for debugging,
install it to zig-cache/bin with:

```
zig build -Dn=19 install
```

To get a list of all possible options, run:

```
zig build -Dn=19 -l

  install          Install 019_functions2.zig to prefix path
  uninstall        Uninstall 019_functions2.zig from prefix path
  test             Run 019_functions2.zig without checking output
  ...
```

To reset the progress (have it run all the exercises that have already been completed):
```
zig build -Dreset
```

## What's Covered

The primary goal for Ziglings is to cover the core Zig language.

It would be nice to cover the Standard Library as well, but this
is currently challenging because the stdlib is evolving even
faster than the core language (and that's saying something!).
Not only would stdlib coverage change very rapidly, some
exercises might even cease to be relevant entirely.

Having said that, there are some stdlib features that are
probably here to stay or are so important to understand that they
are worth the extra effort to keep current.

Conspicuously absent from Ziglings are a lot of string
manipulation exercises. This is because Zig itself largely avoids
dealing with strings. Hopefully there will be an obvious way to
address this in the future. The Ziglings crew loves strings!

Zig Core Language

* [x] Hello world (main needs to be public)
* [x] Importing standard library
* [x] Assignment
* [x] Arrays
* [x] Strings
* [x] If
* [x] While
* [x] For
* [x] Functions
* [x] Errors (error/try/catch/if-else-err)
* [x] Defer (and errdefer)
* [x] Switch
* [x] Unreachable
* [x] Enums
* [x] Structs
* [x] Pointers
* [x] Optionals
* [x] Struct methods
* [x] Slices
* [x] Many-item pointers
* [x] Unions
* [x] Numeric types (integers, floats)
* [x] Labelled blocks and loops
* [x] Loops as expressions
* [x] Builtins
* [x] Inline loops
* [x] Comptime
* [x] Sentinel termination
* [x] Quoted identifiers @""
* [x] Anonymous structs/tuples/lists
* [ ] Async <--- ironically awaiting upstream Zig updates
* [X] Interfaces
* [X] Bit manipulation
* [X] Working with C
* [X] Threading
* [x] Labeled switch
* [x] Vector operations (SIMD)

Zig Standard Library

* [X] String formatting
* [X] Testing
* [X] Tokenization
* [X] File handling

## Contributing

Contributions are very welcome! I'm writing this to teach myself
and to create the learning resource I wished for. There will be
tons of room for improvement:

* Wording of explanations
* Idiomatic usage of Zig
* Additional exercises

Please see [CONTRIBUTING](https://codeberg.org/ziglings/exercises/src/branch/main/CONTRIBUTING.md)
in this repo for the full details.
