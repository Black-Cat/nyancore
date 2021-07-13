const builtin = @import("builtin");
const std = @import("std");

pub fn printErrorNoPanic(comptime module: []const u8, error_message: []const u8) void {
    @setCold(true);

    const stdout = std.io.getStdOut().writer();
    stdout.print("\x1b[1;31m{s} ERROR:\x1b[0m {s}\n", .{ module, error_message }) catch unreachable;
}

pub fn printError(comptime module: []const u8, error_message: []const u8) void {
    @setCold(true);
    printErrorNoPanic(module, error_message);

    if (builtin.mode == .Debug) {
        @panic(error_message);
    }
}
