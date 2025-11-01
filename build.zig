const std = @import("std");
const builtin = @import("builtin");
const tests = @import("test/tests.zig");

const Build = std.Build;
const CompileStep = Build.CompileStep;
const Step = Build.Step;
const Child = std.process.Child;

const assert = std.debug.assert;
const join = std.fs.path.join;
const print = std.debug.print;

// When changing this version, be sure to also update README.md in two places:
//     1) Getting Started
//     2) Version Changes
comptime {
    const required_zig = "0.16.0-dev.1204";
    const current_zig = builtin.zig_version;
    const min_zig = std.SemanticVersion.parse(required_zig) catch unreachable;
    if (current_zig.order(min_zig) == .lt) {
        const error_message =
            \\Sorry, it looks like your version of zig is too old. :-(
            \\
            \\Ziglings requires development build
            \\
            \\{}
            \\
            \\or higher.
            \\
            \\Please download a development ("master") build from
            \\
            \\https://ziglang.org/download/
            \\
            \\
        ;
        @compileError(std.fmt.comptimePrint(error_message, .{min_zig}));
    }
}

const Kind = enum {
    /// Run the artifact as a normal executable.
    exe,
    /// Run the artifact as a test.
    @"test",
};

pub const Exercise = struct {
    /// main_file must have the format key_name.zig.
    /// The key will be used as a shorthand to build just one example.
    main_file: []const u8,

    /// This is the desired output of the program.
    /// A program passes if its output, excluding trailing whitespace, is equal
    /// to this string.
    output: []const u8,

    /// This is an optional hint to give if the program does not succeed.
    hint: ?[]const u8 = null,

    /// By default, we verify output against stderr.
    /// Set this to true to check stdout instead.
    check_stdout: bool = false,

    /// This exercise makes use of C functions.
    /// We need to keep track of this, so we compile with libc.
    link_libc: bool = false,

    /// This exercise kind.
    kind: Kind = .exe,

    /// This exercise is not supported by the current Zig compiler.
    skip: bool = false,

    /// Returns the name of the main file with .zig stripped.
    pub fn name(self: Exercise) []const u8 {
        return std.fs.path.stem(self.main_file);
    }

    /// Returns the key of the main file, the string before the '_' with
    /// "zero padding" removed.
    /// For example, "001_hello.zig" has the key "1".
    pub fn key(self: Exercise) []const u8 {
        // Main file must be key_description.zig.
        const end_index = std.mem.indexOfScalar(u8, self.main_file, '_') orelse
            unreachable;

        // Remove zero padding by advancing index past '0's.
        var start_index: usize = 0;
        while (self.main_file[start_index] == '0') start_index += 1;
        return self.main_file[start_index..end_index];
    }

    /// Returns the exercise key as an integer.
    pub fn number(self: Exercise) usize {
        return std.fmt.parseInt(usize, self.key(), 10) catch unreachable;
    }
};

/// Build mode.
const Mode = enum {
    /// Normal build mode: `zig build`
    normal,
    /// Named build mode: `zig build -Dn=n`
    named,
    /// Random build mode: `zig build -Drandom`
    random,
};

pub const logo =
    \\         _       _ _
    \\     ___(_) __ _| (_)_ __   __ _ ___
    \\    |_  | |/ _' | | | '_ \ / _' / __|
    \\     / /| | (_| | | | | | | (_| \__ \
    \\    /___|_|\__, |_|_|_| |_|\__, |___/
    \\           |___/           |___/
    \\
    \\    "Look out! Broken programs below!"
    \\
    \\
;

const progress_filename = ".progress.txt";

pub fn build(b: *Build) !void {
    if (!validate_exercises()) std.process.exit(2);

    use_color_escapes = false;
    if (std.fs.File.stderr().supportsAnsiEscapeCodes()) {
        use_color_escapes = true;
    } else if (builtin.os.tag == .windows) {
        const w32 = struct {
            const DWORD = std.os.windows.DWORD;
            const ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;
            const STD_ERROR_HANDLE: DWORD = @bitCast(@as(i32, -12));
            const GetStdHandle = std.os.windows.kernel32.GetStdHandle;
            const GetConsoleMode = std.os.windows.kernel32.GetConsoleMode;
            const SetConsoleMode = std.os.windows.kernel32.SetConsoleMode;
        };
        const handle = w32.GetStdHandle(w32.STD_ERROR_HANDLE).?;
        var mode: w32.DWORD = 0;
        if (w32.GetConsoleMode(handle, &mode) != 0) {
            mode |= w32.ENABLE_VIRTUAL_TERMINAL_PROCESSING;
            use_color_escapes = w32.SetConsoleMode(handle, mode) != 0;
        }
    }

    if (use_color_escapes) {
        red_text = "\x1b[31m";
        red_bold_text = "\x1b[31;1m";
        red_dim_text = "\x1b[31;2m";
        green_text = "\x1b[32m";
        bold_text = "\x1b[1m";
        reset_text = "\x1b[0m";
    }

    // Remove the standard install and uninstall steps.
    b.top_level_steps = .{};

    const healed = b.option(bool, "healed", "Run exercises from patches/healed") orelse
        false;
    const override_healed_path = b.option([]const u8, "healed-path", "Override healed path");
    const exno: ?usize = b.option(usize, "n", "Select exercise");
    const rand: ?bool = b.option(bool, "random", "Select random exercise");
    const start: ?usize = b.option(usize, "s", "Start at exercise");
    const reset: ?bool = b.option(bool, "reset", "Reset exercise progress");

    const sep = std.fs.path.sep_str;
    const healed_path = if (override_healed_path) |path|
        path
    else
        "patches" ++ sep ++ "healed";
    const work_path = if (healed) healed_path else "exercises";

    const header_step = PrintStep.create(b, logo);

    if (exno) |n| {
        // Named build mode: verifies a single exercise.
        if (n == 0 or n > exercises.len - 1) {
            print("unknown exercise number: {}\n", .{n});
            std.process.exit(2);
        }
        const ex = exercises[n - 1];

        const zigling_step = b.step(
            "zigling",
            b.fmt("Check the solution of {s}", .{ex.main_file}),
        );
        b.default_step = zigling_step;
        zigling_step.dependOn(&header_step.step);

        const verify_step = ZiglingStep.create(b, ex, work_path, .named);
        verify_step.step.dependOn(&header_step.step);

        zigling_step.dependOn(&verify_step.step);

        return;
    }

    if (rand) |_| {
        // Random build mode: verifies one random exercise.
        // like for 'exno' but chooses a random exercise number.
        print("work in progress: check a random exercise\n", .{});

        var prng = std.Random.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try std.posix.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        });
        const rnd = prng.random();
        const ex = exercises[rnd.intRangeLessThan(usize, 0, exercises.len)];

        print("random exercise: {s}\n", .{ex.main_file});

        const zigling_step = b.step(
            "random",
            b.fmt("Check the solution of {s}", .{ex.main_file}),
        );
        b.default_step = zigling_step;
        zigling_step.dependOn(&header_step.step);
        const verify_step = ZiglingStep.create(b, ex, work_path, .random);
        verify_step.step.dependOn(&header_step.step);
        zigling_step.dependOn(&verify_step.step);
        return;
    }

    if (start) |s| {
        if (s == 0 or s > exercises.len - 1) {
            print("unknown exercise number: {}\n", .{s});
            std.process.exit(2);
        }
        const first = exercises[s - 1];
        const ziglings_step = b.step("ziglings", b.fmt("Check ziglings starting with {s}", .{first.main_file}));
        b.default_step = ziglings_step;

        var prev_step = &header_step.step;
        for (exercises[(s - 1)..]) |ex| {
            const verify_stepn = ZiglingStep.create(b, ex, work_path, .normal);
            verify_stepn.step.dependOn(prev_step);

            prev_step = &verify_stepn.step;
        }
        ziglings_step.dependOn(prev_step);
        return;
    }

    if (reset) |_| {
        std.fs.cwd().deleteFile(progress_filename) catch |err| {
            switch (err) {
                std.fs.Dir.DeleteFileError.FileNotFound => {},
                else => {
                    print("Unable to remove progress file, Error: {}\n", .{err});
                    return err;
                },
            }
        };

        print("Progress reset, {s} removed.\n", .{progress_filename});
        std.process.exit(0);
    }

    // Normal build mode: verifies all exercises according to the recommended
    // order.
    const ziglings_step = b.step("ziglings", "Check all ziglings");
    b.default_step = ziglings_step;

    var prev_step = &header_step.step;

    var starting_exercise: u32 = 0;

    if (std.fs.cwd().openFile(progress_filename, .{})) |progress_file| {
        defer progress_file.close();

        const progress_file_size = try progress_file.getEndPos();

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();
        const contents = try allocator.alloc(u8, progress_file_size);
        defer allocator.free(contents);
        const bytes_read = try progress_file.read(contents);
        if (bytes_read != progress_file_size) {
            return error.UnexpectedEOF;
        }

        starting_exercise = try std.fmt.parseInt(u32, contents, 10);
    } else |err| {
        switch (err) {
            std.fs.File.OpenError.FileNotFound => {
                // This is fine, may be the first time tests are run or progress have been reset
            },
            else => {
                print("Unable to open {s}: {}\n", .{ progress_filename, err });
                return err;
            },
        }
    }

    for (exercises) |ex| {
        if (starting_exercise < ex.number()) {
            const verify_stepn = ZiglingStep.create(b, ex, work_path, .normal);
            verify_stepn.step.dependOn(prev_step);

            prev_step = &verify_stepn.step;
        }
    }
    ziglings_step.dependOn(prev_step);

    const test_step = b.step("test", "Run all the tests");
    test_step.dependOn(tests.addCliTests(b, &exercises));
}

var use_color_escapes = false;
var red_text: []const u8 = "";
var red_bold_text: []const u8 = "";
var red_dim_text: []const u8 = "";
var green_text: []const u8 = "";
var bold_text: []const u8 = "";
var reset_text: []const u8 = "";

const ZiglingStep = struct {
    step: Step,
    exercise: Exercise,
    work_path: []const u8,
    mode: Mode,

    pub fn create(
        b: *Build,
        exercise: Exercise,
        work_path: []const u8,
        mode: Mode,
    ) *ZiglingStep {
        const self = b.allocator.create(ZiglingStep) catch @panic("OOM");
        self.* = .{
            .step = Step.init(.{
                .id = .custom,
                .name = exercise.main_file,
                .owner = b,
                .makeFn = make,
            }),
            .exercise = exercise,
            .work_path = work_path,
            .mode = mode,
        };
        return self;
    }

    fn make(step: *Step, options: Step.MakeOptions) !void {
        // NOTE: Using exit code 2 will prevent the Zig compiler to print the message:
        // "error: the following build command failed with exit code 1:..."
        const self: *ZiglingStep = @alignCast(@fieldParentPtr("step", step));

        if (self.exercise.skip) {
            print("Skipping {s}\n\n", .{self.exercise.main_file});

            return;
        }

        const exe_path = self.compile(options.progress_node) catch {
            self.printErrors();

            if (self.exercise.hint) |hint|
                print("\n{s}Ziglings hint: {s}{s}", .{ bold_text, hint, reset_text });

            self.help();
            std.process.exit(2);
        };

        self.run(exe_path, options.progress_node) catch {
            self.printErrors();

            if (self.exercise.hint) |hint|
                print("\n{s}Ziglings hint: {s}{s}", .{ bold_text, hint, reset_text });

            self.help();
            std.process.exit(2);
        };

        // Print possible warning/debug messages.
        self.printErrors();
    }

    fn run(self: *ZiglingStep, exe_path: []const u8, _: std.Progress.Node) !void {
        resetLine();
        print("Checking: {s}\n", .{self.exercise.main_file});

        const b = self.step.owner;

        // Allow up to 1 MB of stdout capture.
        const max_output_bytes = 1 * 1024 * 1024;

        const result = Child.run(.{
            .allocator = b.allocator,
            .argv = &.{exe_path},
            .cwd = b.build_root.path.?,
            .cwd_dir = b.build_root.handle,
            .max_output_bytes = max_output_bytes,
        }) catch |err| {
            return self.step.fail("unable to spawn {s}: {s}", .{
                exe_path, @errorName(err),
            });
        };

        switch (self.exercise.kind) {
            .exe => return self.check_output(result),
            .@"test" => return self.check_test(result),
        }
    }

    fn check_output(self: *ZiglingStep, result: Child.RunResult) !void {
        const b = self.step.owner;

        // Make sure it exited cleanly.
        switch (result.term) {
            .Exited => |code| {
                if (code != 0) {
                    return self.step.fail("{s} exited with error code {d} (expected {})", .{
                        self.exercise.main_file, code, 0,
                    });
                }
            },
            else => {
                return self.step.fail("{s} terminated unexpectedly", .{
                    self.exercise.main_file,
                });
            },
        }

        const raw_output = if (self.exercise.check_stdout)
            result.stdout
        else
            result.stderr;

        // Validate the output.
        // NOTE: exercise.output can never contain a CR character.
        // See https://ziglang.org/documentation/master/#Source-Encoding.
        const output = trimLines(b.allocator, raw_output) catch @panic("OOM");
        const exercise_output = self.exercise.output;
        if (!std.mem.eql(u8, output, self.exercise.output)) {
            const red = red_bold_text;
            const reset = reset_text;

            // Override the coloring applied by the printError method.
            // NOTE: the first red and the last reset are not necessary, they
            // are here only for alignment.
            return self.step.fail(
                \\
                \\{s}========= expected this output: =========={s}
                \\{s}
                \\{s}========= but found: ====================={s}
                \\{s}
                \\{s}=========================================={s}
            , .{ red, reset, exercise_output, red, reset, output, red, reset });
        }

        const progress = try std.fmt.allocPrint(b.allocator, "{d}", .{self.exercise.number()});
        defer b.allocator.free(progress);

        const file = try std.fs.cwd().createFile(
            progress_filename,
            .{ .read = true, .truncate = true },
        );
        defer file.close();

        try file.writeAll(progress);
        try file.sync();

        print("{s}PASSED:\n{s}{s}\n\n", .{ green_text, output, reset_text });
    }

    fn check_test(self: *ZiglingStep, result: Child.RunResult) !void {
        switch (result.term) {
            .Exited => |code| {
                if (code != 0) {
                    // The test failed.
                    const stderr = std.mem.trimRight(u8, result.stderr, " \r\n");

                    return self.step.fail("\n{s}", .{stderr});
                }
            },
            else => {
                return self.step.fail("{s} terminated unexpectedly", .{
                    self.exercise.main_file,
                });
            },
        }

        print("{s}PASSED{s}\n\n", .{ green_text, reset_text });
    }

    fn compile(self: *ZiglingStep, prog_node: std.Progress.Node) ![]const u8 {
        print("Compiling: {s}\n", .{self.exercise.main_file});

        const b = self.step.owner;
        const exercise_path = self.exercise.main_file;
        const path = join(b.allocator, &.{ self.work_path, exercise_path }) catch
            @panic("OOM");

        var zig_args = std.array_list.Managed([]const u8).init(b.allocator);
        defer zig_args.deinit();

        zig_args.append(b.graph.zig_exe) catch @panic("OOM");

        const cmd = switch (self.exercise.kind) {
            .exe => "build-exe",
            .@"test" => "test",
        };
        zig_args.append(cmd) catch @panic("OOM");

        // Enable C support for exercises that use C functions.
        if (self.exercise.link_libc) {
            zig_args.append("-lc") catch @panic("OOM");
        }

        if (b.reference_trace) |rt| {
            zig_args.append(b.fmt("-freference-trace={}", .{rt})) catch @panic("OOM");
        }

        zig_args.append(b.pathFromRoot(path)) catch @panic("OOM");

        zig_args.append("--cache-dir") catch @panic("OOM");
        zig_args.append(b.pathFromRoot(b.cache_root.path.?)) catch @panic("OOM");

        zig_args.append("--listen=-") catch @panic("OOM");

        //
        // NOTE: After many changes in zig build system, we need to create the cache path manually.
        // See https://github.com/ziglang/zig/pull/21115
        // Maybe there is a better way (in the future).
        const exe_dir = try self.step.evalZigProcess(zig_args.items, prog_node, false, null, b.allocator);
        const exe_name = switch (self.exercise.kind) {
            .exe => self.exercise.name(),
            .@"test" => "test",
        };
        const sep = std.fs.path.sep_str;
        const root_path = exe_dir.?.root_dir.path.?;
        const sub_path = exe_dir.?.subPathOrDot();
        const exe_path = b.fmt("{s}{s}{s}{s}{s}", .{ root_path, sep, sub_path, sep, exe_name });

        return exe_path;
    }

    fn help(self: *ZiglingStep) void {
        const b = self.step.owner;
        const key = self.exercise.key();
        const path = self.exercise.main_file;

        const cmd = switch (self.mode) {
            .normal => "zig build",
            .named => b.fmt("zig build -Dn={s}", .{key}),
            .random => "zig build -Drandom",
        };

        print("\n{s}Edit exercises/{s} and run '{s}' again.{s}\n", .{
            red_bold_text, path, cmd, reset_text,
        });
    }

    fn printErrors(self: *ZiglingStep) void {
        resetLine();

        // Display error/warning messages.
        if (self.step.result_error_msgs.items.len > 0) {
            for (self.step.result_error_msgs.items) |msg| {
                print("{s}error: {s}{s}{s}{s}\n", .{
                    red_bold_text, reset_text, red_dim_text, msg, reset_text,
                });
            }
        }

        // Render compile errors at the bottom of the terminal.
        // TODO: use the same ttyconf from the builder.
        const color: std.zig.Color = if (use_color_escapes)
            .on
        else
            .off;
        if (self.step.result_error_bundle.errorMessageCount() > 0) {
            self.step.result_error_bundle.renderToStdErr(.{}, color);
        }
    }
};

/// Clears the entire line and move the cursor to column zero.
/// Used for clearing the compiler and build_runner progress messages.
fn resetLine() void {
    if (use_color_escapes) print("{s}", .{"\x1b[2K\r"});
}

/// Removes trailing whitespace for each line in buf, also ensuring that there
/// are no trailing LF characters at the end.
pub fn trimLines(allocator: std.mem.Allocator, buf: []const u8) ![]const u8 {
    var list = try std.array_list.Aligned(u8, null).initCapacity(allocator, buf.len);

    var iter = std.mem.splitSequence(u8, buf, " \n");
    while (iter.next()) |line| {
        // TODO: trimming CR characters is probably not necessary.
        const data = std.mem.trimRight(u8, line, " \r");
        try list.appendSlice(allocator, data);
        try list.append(allocator, '\n');
    }

    const result = try list.toOwnedSlice(allocator); // TODO: probably not necessary

    // Remove the trailing LF character, that is always present in the exercise
    // output.
    return std.mem.trimRight(u8, result, "\n");
}

/// Prints a message to stderr.
const PrintStep = struct {
    step: Step,
    message: []const u8,

    pub fn create(owner: *Build, message: []const u8) *PrintStep {
        const self = owner.allocator.create(PrintStep) catch @panic("OOM");
        self.* = .{
            .step = Step.init(.{
                .id = .custom,
                .name = "print",
                .owner = owner,
                .makeFn = make,
            }),
            .message = message,
        };

        return self;
    }

    fn make(step: *Step, _: Step.MakeOptions) !void {
        const self: *PrintStep = @alignCast(@fieldParentPtr("step", step));
        print("{s}", .{self.message});
    }
};

/// Checks that each exercise number, excluding the last, forms the sequence
/// `[1, exercise.len)`.
///
/// Additionally check that the output field lines doesn't have trailing whitespace.
fn validate_exercises() bool {
    // Don't use the "multi-object for loop" syntax, in order to avoid a syntax
    // error with old Zig compilers.
    var i: usize = 0;
    for (exercises[0..]) |ex| {
        const exno = ex.number();
        const last = 999;
        i += 1;

        if (exno != i and exno != last) {
            print("exercise {s} has an incorrect number: expected {}, got {s}\n", .{
                ex.main_file, i, ex.key(),
            });

            return false;
        }

        var iter = std.mem.splitScalar(u8, ex.output, '\n');
        while (iter.next()) |line| {
            const output = std.mem.trimRight(u8, line, " \r");
            if (output.len != line.len) {
                print("exercise {s} output field lines have trailing whitespace\n", .{
                    ex.main_file,
                });

                return false;
            }
        }

        if (!std.mem.endsWith(u8, ex.main_file, ".zig")) {
            print("exercise {s} is not a zig source file\n", .{ex.main_file});

            return false;
        }
    }

    return true;
}

const exercises = [_]Exercise{
    .{
        .main_file = "001_hello.zig",
        .output = "Hello world!",
        .hint =
        \\DON'T PANIC!
        \\Read the compiler messages above. (Something about 'main'?)
        \\Open up the source file as noted below and read the comments.
        \\
        \\(Hints like these will occasionally show up, but for the
        \\most part, you'll be taking directions from the Zig
        \\compiler itself.)
        \\
        ,
    },
    .{
        .main_file = "002_std.zig",
        .output = "Standard Library.",
    },
    .{
        .main_file = "003_assignment.zig",
        .output = "55 314159 -11",
        .hint = "There are three mistakes in this one!",
    },
    .{
        .main_file = "004_arrays.zig",
        .output = "First: 2, Fourth: 7, Length: 8",
        .hint = "There are two things to complete here.",
    },
    .{
        .main_file = "005_arrays2.zig",
        .output = "LEET: 1337, Bits: 100110011001",
        .hint = "Fill in the two arrays.",
    },
    .{
        .main_file = "006_strings.zig",
        .output = "d=d ha ha ha Major Tom",
        .hint = "Each '???' needs something filled in.",
    },
    .{
        .main_file = "007_strings2.zig",
        .output =
        \\Ziggy played guitar
        \\Jamming good with Andrew Kelley
        \\And the Spiders from Mars
        ,
        .hint = "Please fix the lyrics!",
    },
    .{
        .main_file = "008_quiz.zig",
        .output = "Program in Zig!",
        .hint = "See if you can fix the program!",
    },
    .{
        .main_file = "009_if.zig",
        .output = "Foo is 1!",
    },
    .{
        .main_file = "010_if2.zig",
        .output = "With the discount, the price is $17.",
    },
    .{
        .main_file = "011_while.zig",
        .output = "2 4 8 16 32 64 128 256 512 n=1024",
        .hint = "You probably want a 'less than' condition.",
    },
    .{
        .main_file = "012_while2.zig",
        .output = "2 4 8 16 32 64 128 256 512 n=1024",
        .hint = "It might help to look back at the previous exercise.",
    },
    .{
        .main_file = "013_while3.zig",
        .output = "1 2 4 7 8 11 13 14 16 17 19",
    },
    .{
        .main_file = "014_while4.zig",
        .output = "n=4",
    },
    .{
        .main_file = "015_for.zig",
        .output = "A Dramatic Story: :-)  :-)  :-(  :-|  :-)  The End.",
    },
    .{
        .main_file = "016_for2.zig",
        .output = "The value of bits '1101': 13.",
    },
    .{
        .main_file = "017_quiz2.zig",
        .output = "1, 2, Fizz, 4, Buzz, Fizz, 7, 8, Fizz, Buzz, 11, Fizz, 13, 14, FizzBuzz, 16,",
        .hint = "This is a famous game!",
    },
    .{
        .main_file = "018_functions.zig",
        .output = "Answer to the Ultimate Question: 42",
        .hint = "Can you help write the function?",
    },
    .{
        .main_file = "019_functions2.zig",
        .output = "Powers of two: 2 4 8 16",
    },
    .{
        .main_file = "020_quiz3.zig",
        .output = "32 64 128 256",
        .hint = "Unexpected pop quiz! Help!",
    },
    .{
        .main_file = "021_errors.zig",
        .output = "2<4. 3<4. 4=4. 5>4. 6>4.",
        .hint = "What's the deal with fours?",
    },
    .{
        .main_file = "022_errors2.zig",
        .output = "I compiled!",
        .hint = "Get the error union type right to allow this to compile.",
    },
    .{
        .main_file = "023_errors3.zig",
        .output = "a=64, b=22",
    },
    .{
        .main_file = "024_errors4.zig",
        .output = "a=20, b=14, c=10",
    },
    .{
        .main_file = "025_errors5.zig",
        .output = "a=0, b=19, c=0",
    },
    .{
        .main_file = "026_hello2.zig",
        .output = "Hello world!",
        .hint = "Try using a try!",
        .check_stdout = true,
    },
    .{
        .main_file = "027_defer.zig",
        .output = "One Two",
    },
    .{
        .main_file = "028_defer2.zig",
        .output = "(Goat) (Cat) (Dog) (Dog) (Goat) (Unknown) done.",
    },
    .{
        .main_file = "029_errdefer.zig",
        .output = "Getting number...got 5. Getting number...failed!",
    },
    .{
        .main_file = "030_switch.zig",
        .output = "ZIG?",
    },
    .{
        .main_file = "031_switch2.zig",
        .output = "ZIG!",
    },
    .{
        .main_file = "032_unreachable.zig",
        .output = "1 2 3 9 8 7",
    },
    .{
        .main_file = "033_iferror.zig",
        .output = "2<4. 3<4. 4=4. 5>4. 6>4.",
        .hint = "Seriously, what's the deal with fours?",
    },
    .{
        .main_file = "034_quiz4.zig",
        .output = "my_num=42",
        .hint = "Can you make this work?",
        .check_stdout = true,
    },
    .{
        .main_file = "035_enums.zig",
        .output = "1 2 3 9 8 7",
        .hint = "This problem seems familiar...",
    },
    .{
        .main_file = "036_enums2.zig",
        .output =
        \\<p>
        \\  <span style="color: #ff0000">Red</span>
        \\  <span style="color: #00ff00">Green</span>
        \\  <span style="color: #0000ff">Blue</span>
        \\</p>
        ,
        .hint = "I'm feeling blue about this.",
    },
    .{
        .main_file = "037_structs.zig",
        .output = "Your wizard has 90 health and 25 gold.",
    },
    .{
        .main_file = "038_structs2.zig",
        .output =
        \\Character 1 - G:20 H:100 XP:10
        \\Character 2 - G:10 H:100 XP:20
        ,
    },
    .{
        .main_file = "039_pointers.zig",
        .output = "num1: 5, num2: 5",
        .hint = "Pointers aren't so bad.",
    },
    .{
        .main_file = "040_pointers2.zig",
        .output = "a: 12, b: 12",
    },
    .{
        .main_file = "041_pointers3.zig",
        .output = "foo=6, bar=11",
    },
    .{
        .main_file = "042_pointers4.zig",
        .output = "num: 5, more_nums: 1 1 5 1",
    },
    .{
        .main_file = "043_pointers5.zig",
        .output =
        \\Wizard (G:10 H:100 XP:20)
        \\  Mentor: Wizard (G:10000 H:100 XP:2340)
        ,
    },
    .{
        .main_file = "044_quiz5.zig",
        .output = "Elephant A. Elephant B. Elephant C.",
        .hint = "Oh no! We forgot Elephant B!",
    },
    .{
        .main_file = "045_optionals.zig",
        .output = "The Ultimate Answer: 42.",
    },
    .{
        .main_file = "046_optionals2.zig",
        .output = "Elephant A. Elephant B. Elephant C.",
        .hint = "Elephants again!",
    },
    .{
        .main_file = "047_methods.zig",
        .output = "5 aliens. 4 aliens. 1 aliens. 0 aliens. Earth is saved!",
        .hint = "Use the heat ray. And the method!",
    },
    .{
        .main_file = "048_methods2.zig",
        .output = "A  B  C",
        .hint = "This just needs one little fix.",
    },
    .{
        .main_file = "049_quiz6.zig",
        .output = "A  B  C  Cv Bv Av",
        .hint = "Now you're writing Zig!",
    },
    .{
        .main_file = "050_no_value.zig",
        .output = "That is not dead which can eternal lie / And with strange aeons even death may die.",
    },
    .{
        .main_file = "051_values.zig",
        .output = "1:false!. 2:true!. 3:true!. XP before:0, after:200.",
    },
    .{
        .main_file = "052_slices.zig",
        .output =
        \\Hand1: A 4 K 8
        \\Hand2: 5 2 Q J
        ,
    },
    .{
        .main_file = "053_slices2.zig",
        .output = "'all your base are belong to us.' 'for great justice.'",
    },
    .{
        .main_file = "054_manypointers.zig",
        .output = "Memory is a resource.",
    },
    .{
        .main_file = "055_unions.zig",
        .output = "Insect report! Ant alive is: true. Bee visited 15 flowers.",
    },
    .{
        .main_file = "056_unions2.zig",
        .output = "Insect report! Ant alive is: true. Bee visited 16 flowers.",
    },
    .{
        .main_file = "057_unions3.zig",
        .output = "Insect report! Ant alive is: true. Bee visited 17 flowers.",
    },
    .{
        .main_file = "058_quiz7.zig",
        .output = "Archer's Point--2->Bridge--1->Dogwood Grove--3->Cottage--2->East Pond--1->Fox Pond",
        .hint = "This is the biggest program we've seen yet. But you can do it!",
    },
    .{
        .main_file = "059_integers.zig",
        .output = "Zig is cool.",
    },
    .{
        .main_file = "060_floats.zig",
        .output = "Shuttle liftoff weight: 2032 metric tons",
    },
    .{
        .main_file = "061_coercions.zig",
        .output = "Letter: A",
    },
    .{
        .main_file = "062_loop_expressions.zig",
        .output = "Current language: Zig",
        .hint = "Surely the current language is 'Zig'!",
    },
    .{
        .main_file = "063_labels.zig",
        .output = "Enjoy your Cheesy Chili!",
    },
    .{
        .main_file = "064_builtins.zig",
        .output = "1101 + 0101 = 0010 (true). Without overflow: 00010010. Furthermore, 11110000 backwards is 00001111.",
    },
    .{
        .main_file = "065_builtins2.zig",
        .output = "A Narcissus loves all Narcissuses. He has room in his heart for: me myself.",
    },
    .{
        .main_file = "066_comptime.zig",
        .output = "Immutable: 12345, 987.654; Mutable: 54321, 456.789; Types: comptime_int, comptime_float, u32, f32",
        .hint = "It may help to read this one out loud to your favorite stuffed animal until it sinks in completely.",
    },
    .{
        .main_file = "067_comptime2.zig",
        .output = "A BB CCC DDDD",
    },
    .{
        .main_file = "068_comptime3.zig",
        .output =
        \\Minnow (1:32, 4 x 2)
        \\Shark (1:16, 8 x 5)
        \\Whale (1:1, 143 x 95)
        ,
    },
    .{
        .main_file = "069_comptime4.zig",
        .output = "s1={ 1, 2, 3 }, s2={ 1, 2, 3, 4, 5 }, s3={ 1, 2, 3, 4, 5, 6, 7 }",
    },
    .{
        .main_file = "070_comptime5.zig",
        .output =
        \\"Quack." ducky1: true, "Squeek!" ducky2: true, ducky3: false
        ,
        .hint = "Have you kept the wizard hat on?",
    },
    .{
        .main_file = "071_comptime6.zig",
        .output = "Narcissus has room in his heart for: me myself.",
    },
    .{
        .main_file = "072_comptime7.zig",
        .output = "26",
    },
    .{
        .main_file = "073_comptime8.zig",
        .output = "My llama value is 25.",
    },
    .{
        .main_file = "074_comptime9.zig",
        .output = "My llama value is 2.",
        .skip = true,
    },
    .{
        .main_file = "075_quiz8.zig",
        .output = "Archer's Point--2->Bridge--1->Dogwood Grove--3->Cottage--2->East Pond--1->Fox Pond",
        .hint = "Roll up those sleeves. You get to WRITE some code for this one.",
    },
    .{
        .main_file = "076_sentinels.zig",
        .output = "Array:123056. Many-item pointer:123.",
    },
    .{
        .main_file = "077_sentinels2.zig",
        .output = "Weird Data!",
    },
    .{
        .main_file = "078_sentinels3.zig",
        .output = "Weird Data!",
    },
    .{
        .main_file = "079_quoted_identifiers.zig",
        .output = "Sweet freedom: 55, false.",
        .hint = "Help us, Zig Programmer, you're our only hope!",
    },
    .{
        .main_file = "080_anonymous_structs.zig",
        .output = "[Circle(i32): 25,70,15] [Circle(f32): 25.2,71.0,15.7]",
    },
    .{
        .main_file = "081_anonymous_structs2.zig",
        .output = "x:205 y:187 radius:12",
    },
    .{
        .main_file = "082_anonymous_structs3.zig",
        .output =
        \\"0"(bool):true "1"(bool):false "2"(i32):42 "3"(f32):3.141592
        ,
        .hint = "This one is a challenge! But you have everything you need.",
    },
    .{
        .main_file = "083_anonymous_lists.zig",
        .output = "I say hello!",
    },

    // Skipped because of https://github.com/ratfactor/ziglings/issues/163
    // direct link: https://github.com/ziglang/zig/issues/6025
    .{
        .main_file = "084_async.zig",
        .output = "foo() A",
        .hint = "Read the facts. Use the facts.",
        .skip = true,
    },
    .{
        .main_file = "085_async2.zig",
        .output = "Hello async!",
        .skip = true,
    },
    .{
        .main_file = "086_async3.zig",
        .output = "5 4 3 2 1",
        .skip = true,
    },
    .{
        .main_file = "087_async4.zig",
        .output = "1 2 3 4 5",
        .skip = true,
    },
    .{
        .main_file = "088_async5.zig",
        .output = "Example Title.",
        .skip = true,
    },
    .{
        .main_file = "089_async6.zig",
        .output = ".com: Example Title, .org: Example Title.",
        .skip = true,
    },
    .{
        .main_file = "090_async7.zig",
        .output = "beef? BEEF!",
        .skip = true,
    },
    .{
        .main_file = "091_async8.zig",
        .output = "ABCDEF",
        .skip = true,
    },

    .{
        .main_file = "092_interfaces.zig",
        .output =
        \\Daily Insect Report:
        \\Ant is alive.
        \\Bee visited 17 flowers.
        \\Grasshopper hopped 32 meters.
        ,
    },
    .{
        .main_file = "093_hello_c.zig",
        .output = "Hello C from Zig! - C result is 17 chars written.",
        .link_libc = true,
    },
    .{
        .main_file = "094_c_math.zig",
        .output = "The normalized angle of 765.2 degrees is 45.2 degrees.",
        .link_libc = true,
    },
    .{
        .main_file = "095_for3.zig",
        .output = "1 2 4 7 8 11 13 14 16 17 19",
    },
    .{
        .main_file = "096_memory_allocation.zig",
        .output = "Running Average: 0.30 0.25 0.20 0.18 0.22",
    },
    .{
        .main_file = "097_bit_manipulation.zig",
        .output = "x = 1011; y = 1101",
    },
    .{
        .main_file = "098_bit_manipulation2.zig",
        .output = "Is this a pangram? true!",
    },
    .{
        .main_file = "099_formatting.zig",
        .output =
        \\
        \\ X |  1   2   3   4   5   6   7   8   9  10  11  12  13  14  15
        \\---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
        \\ 1 |  1   2   3   4   5   6   7   8   9  10  11  12  13  14  15
        \\
        \\ 2 |  2   4   6   8  10  12  14  16  18  20  22  24  26  28  30
        \\
        \\ 3 |  3   6   9  12  15  18  21  24  27  30  33  36  39  42  45
        \\
        \\ 4 |  4   8  12  16  20  24  28  32  36  40  44  48  52  56  60
        \\
        \\ 5 |  5  10  15  20  25  30  35  40  45  50  55  60  65  70  75
        \\
        \\ 6 |  6  12  18  24  30  36  42  48  54  60  66  72  78  84  90
        \\
        \\ 7 |  7  14  21  28  35  42  49  56  63  70  77  84  91  98 105
        \\
        \\ 8 |  8  16  24  32  40  48  56  64  72  80  88  96 104 112 120
        \\
        \\ 9 |  9  18  27  36  45  54  63  72  81  90  99 108 117 126 135
        \\
        \\10 | 10  20  30  40  50  60  70  80  90 100 110 120 130 140 150
        \\
        \\11 | 11  22  33  44  55  66  77  88  99 110 121 132 143 154 165
        \\
        \\12 | 12  24  36  48  60  72  84  96 108 120 132 144 156 168 180
        \\
        \\13 | 13  26  39  52  65  78  91 104 117 130 143 156 169 182 195
        \\
        \\14 | 14  28  42  56  70  84  98 112 126 140 154 168 182 196 210
        \\
        \\15 | 15  30  45  60  75  90 105 120 135 150 165 180 195 210 225
        ,
    },
    .{
        .main_file = "100_for4.zig",
        .output = "Arrays match!",
    },
    .{
        .main_file = "101_for5.zig",
        .output =
        \\1. Wizard (Gold: 25, XP: 40)
        \\2. Bard (Gold: 11, XP: 17)
        \\3. Bard (Gold: 5, XP: 55)
        \\4. Warrior (Gold: 7392, XP: 21)
        ,
    },
    .{
        .main_file = "102_testing.zig",
        .output = "",
        .kind = .@"test",
    },
    .{
        .main_file = "103_tokenization.zig",
        .output =
        \\My
        \\name
        \\is
        \\Ozymandias
        \\King
        \\of
        \\Kings
        \\Look
        \\on
        \\my
        \\Works
        \\ye
        \\Mighty
        \\and
        \\despair
        \\This little poem has 15 words!
        ,
    },
    .{
        .main_file = "104_threading.zig",
        .output =
        \\Starting work...
        \\thread 1: started.
        \\thread 2: started.
        \\thread 3: started.
        \\Some weird stuff, after starting the threads.
        \\thread 2: finished.
        \\thread 1: finished.
        \\thread 3: finished.
        \\Zig is cool!
        ,
    },
    .{
        .main_file = "105_threading2.zig",
        .output = "PI ≈ 3.14159265",
    },
    .{
        .main_file = "106_files.zig",
        .output = "Successfully wrote 18 bytes.",
    },
    .{
        .main_file = "107_files2.zig",
        .output =
        \\AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
        \\Successfully Read 18 bytes: It's zigling time!
        ,
    },
    .{
        .main_file = "108_labeled_switch.zig",
        .output = "The pull request has been merged.",
    },
    .{
        .main_file = "109_vectors.zig",
        .output =
        \\Max difference (old fn): 0.014
        \\Max difference (new fn): 0.014
        ,
    },
    .{ .main_file = "110_quiz9.zig", .output = 
    \\Toggle pins with XOR on PORTB
    \\-----------------------------
    \\  1100 // (initial state of PORTB)
    \\^ 0101 // (bitmask)
    \\= 1001
    \\
    \\  1100 // (initial state of PORTB)
    \\^ 0011 // (bitmask)
    \\= 1111
    \\
    \\Set pins with OR on PORTB
    \\-------------------------
    \\  1001 // (initial state of PORTB)
    \\| 0100 // (bitmask)
    \\= 1101
    \\
    \\  1001 // (reset state)
    \\| 0100 // (bitmask)
    \\= 1101
    \\
    \\Clear pins with AND and NOT on PORTB
    \\------------------------------------
    \\  1110 // (initial state of PORTB)
    \\& 1011 // (bitmask)
    \\= 1010
    \\
    \\  0111 // (reset state)
    \\& 1110 // (bitmask)
    \\= 0110
    },
    .{
        .main_file = "999_the_end.zig",
        .output =
        \\
        \\This is the end for now!
        \\We hope you had fun and were able to learn a lot, so visit us again when the next exercises are available.
        ,
    },
};
