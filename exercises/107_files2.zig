//
// Prerequisite :
//    - exercise/106_files.zig, or
//    - create a file {project_root}/output/zigling.txt
//      with content `It's zigling time!`(18 byte total)
//
// Now there no point in writing to a file if we don't read from it am I right?
// let's wrote a program to read the content of the file that we just created.
//
// I am assuming you've created the appropriate files for this to work.
//
// Alright, bud, lean in close here's the game plan.
//    - First, we open the {project_root}/output/ directory
//    - Secondly, we open file `zigling.txt` in that directory
//    - then, we initalize an array of character with all letter 'A', and print it
//    - Afte that, we read the content of the file to the array
//    - Finally, we print out the read content

const std = @import("std");

pub fn main() !void {
    // Get the current working directory
    const cwd = std.fs.cwd();

    // try to open ./output assuming you did your 106_files exercise
    var output_dir = try cwd.openDir("output", .{});
    defer output_dir.close();

    // try to open the file
    const file = try output_dir.openFile("zigling.txt", .{});
    defer file.close();

    // initalize an array of u8 with all letter 'A'.
    // we need to pick a size of the array, 64 seems like a good number.
    // fix the initalization below
    var content = ['A']*64;
    // this should print out : `AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA`
    std.debug.print("{s}\n", .{content});

    // okay, seem like threat of violence is not the answer in this case
    // can you go here to find a way to read the content ?
    // https://ziglang.org/documentation/master/std/#std.fs.File
    // hint: you might find two answer that are both vaild in this case
    const byte_read = zig_read_the_file_or_i_will_fight_you(&content);

    // Woah, too screamy, I know you're excited for zigling time but tone it down a bit
    // Can you print only what we read from the file ?
    std.debug.print("Successfully Read {d} byte: {s}\n", .{
        byte_read,
        content, // change this line only
    });
}
