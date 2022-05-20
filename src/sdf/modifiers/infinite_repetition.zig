const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Infinite Repetition",
    .data_size = @sizeOf(Data),

    .function_definition = "",
    .enter_command_fn = enterCommand,
    .exit_command_fn = exitCommand,
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {
    period: f32,
};

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const next_point: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, "p{d}", .{iter}) catch unreachable;

    const format: []const u8 = "vec3 {s} = mod({s} + .5 * {d:.5}, {d:.5}) - .5 * {d:.5};";
    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        next_point,
        ctxt.cur_point_name,
        data.period,
        data.period,
        data.period,
    }) catch unreachable;

    ctxt.pushPointName(next_point);

    return res;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;
    _ = buffer;

    ctxt.popPointName();
    return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    _ = buffer;
    _ = children;

    bound.* = .{
        .pos = util.math.Vec3.zeros(),
        .r = util.std.math.inf(f32),
    };
}
