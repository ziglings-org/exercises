//
// A labeled switch in zig allows the usage of continue and break
// just like loops, these allow you to create very concise
// Finite State Automata to represent state transitions
//
//      foo: switch (state) {
//          1 => continue :foo 2,
//          2 => continue :foo 3,
//          3 => break :foo,
//          4 => {},
//         ...
//     }
//
const std = @import("std");

const PullRequestState = enum(u8) {
    Draft,
    InReview,
    Approved,
    Rejected,
    Merged,
};

pub fn main() void {
    // Oh no, your pull request keeps being rejected,
    // how would you fix it?
    pr: switch (@as(PullRequestState, PullRequestState.Draft)) {
        PullRequestState.Draft => continue :pr PullRequestState.InReview,
        PullRequestState.InReview => continue :pr PullRequestState.Rejected,
        PullRequestState.Approved => continue :pr PullRequestState.Merged,
        PullRequestState.Rejected => {
            std.debug.print("The pull request has been rejected", .{});
            return;
        },
        PullRequestState.Merged => break, // Would you know where to break to?
    }
    std.debug.print("The pull request has been merged", .{});
}
