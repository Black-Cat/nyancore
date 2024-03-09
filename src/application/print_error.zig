const nyancore_options = @import("nyancore_options");

const builtin = @import("builtin");
const std = @import("std");

pub fn printErrorNoPanic(comptime module: []const u8, error_message: []const u8) void {
    @setCold(true);

    const stdout = std.io.getStdOut().writer();
    stdout.print("\x1b[1;31m{s} ERROR:\x1b[0m {s}\n", .{ module, error_message }) catch unreachable;

    if (nyancore_options.panic_on_all_errors)
        @panic(error_message);
}

pub fn printError(comptime module: []const u8, error_message: []const u8) void {
    @setCold(true);
    printErrorNoPanic(module, error_message);

    if (builtin.mode == .Debug)
        @panic(error_message);
}

pub fn printZigErrorNoPanic(comptime module: []const u8, comptime error_message: []const u8, err: anyerror) void {
    @setCold(true);

    const stdout = std.io.getStdOut().writer();
    stdout.print("\x1b[1;31m{s} ERROR:\x1b[0m {s} {{{any}}}\n", .{ module, error_message, err }) catch unreachable;

    if (nyancore_options.panic_on_all_errors)
        @panic(error_message);
}

pub fn printZigError(comptime module: []const u8, comptime error_message: []const u8, err: anyerror) void {
    @setCold(true);
    printZigErrorNoPanic(module, error_message, err);

    if (builtin.mode == .Debug)
        @panic(error_message);
}
