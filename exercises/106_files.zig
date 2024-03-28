//
// Until now, we've only been printing our output in the console,
// which is good enough for fighting alien and hermit bookkeeping.
//
// However, many other task require some interaction with the file system,
// which is the underlying structure for organizing files on your computer.
//
// The File System provide a hierarchical structure for storing files
// by organizing files into directories, which hold files and other directories,
// thus creating a tree structure for navigating.
//
// Fortunately, zig standard library provide a simple api for interacting
// with the file system, see the detail documentation here
//
// https://ziglang.org/documentation/master/std/#std.fs
//
// In this exercise, we'll try to
//   - create a new directory
//   - open a file in the directory
//   - write to the file.
//
// import std as always
const std = @import("std");

pub fn main() !void {
    // first we get the current working directory
    const cwd: std.fs.Dir = std.fs.cwd();

    // then we'll try to make a new directory /output/
    // to put our output files.
    cwd.makeDir("output") catch |e| switch (e) {
        // there are chance you might want to run this
        // program more than once and the path might already
        // been created, so we'll have to handle this error
        // by doing nothing
        //
        // we want to catch error.PathAlreadyExists and do nothing
        ??? => {},
        // if is any other unexpected error we just propagate it through
        else => return e,
    };

    // then we'll try to open our freshly created directory
    // wait a minute
    // opening a directory might fail!
    // what should we do here?
    var output_dir: std.fs.Dir = cwd.openDir("output", .{});
    defer output_dir.close();

    // we try to open the file `zigling.txt`,
    // and propagate the error up if there are any errors
    const file: std.fs.File = try output_dir.createFile("zigling.txt", .{});
    // it is a good habit to close a file after you are done with
    // so that other program can read it and prevent data corruption
    // but here we are not yet done writing to the file
    // if only there are a keyword in zig that
    // allow you "defer" code execute to the end of scope...
    file.close();

    // !you are not allow to switch this two lines to before file closing line!
    const byte_written = try file.write("It's zigling time!");
    std.debug.print("Successfully wrote {d} bytes.\n", .{byte_written});
}
// to check if you actually write to the file, you can either,
// 1. open the file on your text editor, or
// 2. print the content of the file in the console with command
//    >> cat ./output/zigling.txt
//
//
// More on Creating files
//
// notice in:
// ... try output_dir.createFile("zigling.txt", .{});
//                                              ^^^
//                 we passed this anonymous struct to the function call
//
// this is the struct `CreateFlag` with default fields
// {
//      read: bool = false,
//      truncate: bool = true,
//      exclusive: bool = false,
//      lock: Lock = .none,
//      lock_nonblocking: bool = false,
//      mode: Mode = default_mode
// }
//
// Question:
//   - what should you do if you want to also read the file after opening it?
//   - go to documentation of the struct `std.fs.Dir` here
//     https://ziglang.org/documentation/master/std/#std.fs.Dir
//       - can you find a function for opening a file? how about deleting a file?
//       - what kind of option can you uses with those function?
