const std = @import("std");
const sdf = @import("sdf.zig");
const math = @import("../math/math.zig");

pub const SdfInfo = struct {
    name: []const u8,
    data_size: usize,

    function_definition: []const u8,
    enter_command_fn: sdf.EnterCommandFn,
    exit_command_fn: sdf.ExitCommandFn = undefined, // Not used in materials
    append_mat_check_fn: sdf.AppendMatCheckFn = appendNoMatCheck,

    sphere_bound_fn: sdf.SphereBoundFn = noSphereBoundChange,
};

pub fn appendNoMatCheck(ctxt: *sdf.IterationContext, exit_command: []const u8, buffer: *[]u8, mat_offset: usize, alloc: std.mem.Allocator) []const u8 {
    _ = ctxt;
    _ = buffer;
    _ = mat_offset;

    return alloc.dupe(u8, exit_command) catch unreachable;
}

pub fn noSphereBoundChange(buffer: *[]u8, bound: *math.sphereBound, children: []math.sphereBound) void {
    _ = buffer;
    _ = bound;
    _ = children;
}
