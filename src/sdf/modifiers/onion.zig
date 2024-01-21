const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Onion",
    .data_size = @sizeOf(Data),

    .function_definition = "",
    .enter_command_fn = enterCommand,
    .exit_command_fn = exitCommand,
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {
    thickness: f32,
};

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;
    _ = buffer;

    ctxt.pushEnterInfo(iter);
    ctxt.pushStackInfo(iter, 0);

    return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;

    const data: *Data = @ptrCast(@alignCast(buffer.ptr));
    const ei: util.EnterInfo = ctxt.popEnterInfo();

    const format: []const u8 = "float d{d} = abs(d{d}) - {d:.5};";
    const broken_stack: []const u8 = "float d{d} = 1e10;";

    var res: []const u8 = undefined;
    if (ei.enter_index == ctxt.last_value_set_index) {
        res = util.std.fmt.allocPrint(ctxt.allocator, broken_stack, .{ei.enter_index}) catch unreachable;
    } else {
        res = util.std.fmt.allocPrint(ctxt.allocator, format, .{
            ei.enter_index,
            ctxt.last_value_set_index,
            data.thickness,
        }) catch unreachable;
    }

    ctxt.dropPreviousValueIndexes(ei.enter_stack);

    return res;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    children[0].r += data.thickness;
    bound.* = children[0];
}
