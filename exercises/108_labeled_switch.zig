//
// A labeled switch in zig allows the usage of continue and break
// just like loops, these allow you to create very concise
// Finite State Automata to represent state transitions
//
//      foo: switch (state) {
//          1 => continue :foo 2,
//          2 => continue :foo 3,
//          3 => return,
//          4 => {},
//         ...
//     }
//
const std = @import("std");

const PullRequestState = enum {
    Draft,
    InReview,
    Approved,
    Rejected,
    Merged,
};

pub fn main() void {
    // Something is wrong, it seems your Pull Request can never be merged
    // try to fix it!
    pr: switch (@as(PullRequestState, PullRequestState.Draft)) {
        PullRequestState.Draft => continue :pr PullRequestState.InReview,
        PullRequestState.InReview => continue :pr PullRequestState.Rejected,
        PullRequestState.Approved => continue :pr PullRequestState.Merged,
        PullRequestState.Rejected => std.debug.print("The pull request has been rejected", .{}),
        PullRequestState.Merged => std.debug.print("The pull request has been merged", .{}),
    }
}
