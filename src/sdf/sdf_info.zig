const std = @import("std");
const sdf = @import("sdf.zig");

pub const SdfInfo = struct {
    name: []const u8,
    data_size: usize,

    function_definition: []const u8,
    enter_command_fn: sdf.EnterCommandFn,
    exit_command_fn: sdf.ExitCommandFn = undefined, // Not used in materials
    append_mat_check_fn: sdf.AppendMatCheckFn = appendNoMatCheck,
};

pub fn appendNoMatCheck(exit_command: []const u8, buffer: *[]u8, mat_offset: usize, alloc: std.mem.Allocator) []const u8 {
    _ = buffer;
    _ = mat_offset;

    return alloc.dupe(u8, exit_command) catch unreachable;
}
