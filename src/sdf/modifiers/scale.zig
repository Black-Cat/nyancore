const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Scale",
    .data_size = @sizeOf(Data),

    .function_definition = "",
    .enter_command_fn = enterCommand,
    .exit_command_fn = exitCommand,
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {
    scale: f32,
};

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const next_point: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, "p{d}", .{iter}) catch unreachable;

    const format: []const u8 = "vec3 {s} = {s} / {d:.5};";
    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        next_point,
        ctxt.cur_point_name,
        data.scale,
    }) catch unreachable;

    ctxt.pushPointName(next_point);

    ctxt.pushEnterInfo(iter);
    ctxt.pushStackInfo(iter, 0);

    return res;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));
    const ei: util.EnterInfo = ctxt.popEnterInfo();

    ctxt.popPointName();

    const format: []const u8 = "float d{d} = d{d} * {d:.5};";
    const broken_stack: []const u8 = "float d{d} = 1e10;";

    var res: []const u8 = undefined;
    if (ei.enter_index == ctxt.last_value_set_index) {
        res = util.std.fmt.allocPrint(ctxt.allocator, broken_stack, .{ei.enter_index}) catch unreachable;
    } else {
        res = util.std.fmt.allocPrint(ctxt.allocator, format, .{
            ei.enter_index,
            ctxt.last_value_set_index,
            data.scale,
        }) catch unreachable;
    }

    ctxt.dropPreviousValueIndexes(ei.enter_stack);

    return res;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    children[0].r *= data.scale;
    bound.* = children[0];
}
