const builtin = @import("builtin");
const std = @import("std");

pub fn printError(comptime module: []const u8, error_message: []const u8) void {
    @setCold(true);

    const stdout = std.io.getStdOut().writer();
    stdout.print("\x1b[1;31m{} ERROR:\x1b[0m {}\n", .{ module, error_message }) catch unreachable;

    if (builtin.mode == .Debug) {
        @panic(error_message);
    }
}
