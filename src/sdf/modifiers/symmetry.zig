const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Symmetry",
    .data_size = @sizeOf(Data),

    .function_definition = "",
    .enter_command_fn = enterCommand,
    .exit_command_fn = exitCommand,
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {
    axis: i32,
};

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    if (data.axis == 0)
        return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;

    const next_point: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, "p{d}", .{iter}) catch unreachable;

    const letters: [3][]const u8 = .{
        if (data.axis & (1 << 0) != 0) "x" else "",
        if (data.axis & (1 << 1) != 0) "y" else "",
        if (data.axis & (1 << 2) != 0) "z" else "",
    };
    const temp: []const u8 = util.std.mem.concat(ctxt.allocator, u8, letters[0..]) catch unreachable;

    const format: []const u8 = "vec3 {s} = {s}; {s}.{s} = abs({s}.{s});";
    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        next_point,
        ctxt.cur_point_name,
        next_point,
        temp,
        ctxt.cur_point_name,
        temp,
    }) catch unreachable;

    ctxt.pushPointName(next_point);

    ctxt.allocator.free(temp);

    return res;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    if (data.axis == 0)
        ctxt.popPointName();

    return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    var sym_bound: util.math.sphereBound = children[0];
    var i: usize = 0;
    while (i < 3) : (i += 1)
        sym_bound.pos[i] *= @intToFloat(f32, (data.axis & (@as(i32, 1) << @intCast(u5, i)))) * -1.0;

    bound.* = util.math.SphereBound.merge(children[0], sym_bound);
}
