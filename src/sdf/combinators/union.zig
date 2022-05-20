const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Union",
    .data_size = @sizeOf(Data),

    .function_definition = "",
    .enter_command_fn = enterCommand,
    .exit_command_fn = exitCommand,
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {};

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;
    _ = buffer;

    ctxt.pushEnterInfo(iter);
    ctxt.pushStackInfo(iter, 0);

    return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;
    _ = buffer;

    const ei: util.EnterInfo = ctxt.popEnterInfo();

    const command: []const u8 = "d{d} = min(d{d}, d{d});";
    const res: []const u8 = util.combinatorExitCommand(command, ei.enter_stack, ei.enter_index, ctxt);

    ctxt.dropPreviousValueIndexes(ei.enter_stack);

    return res;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    _ = buffer;

    if (children.len == 1) {
        bound.* = children[0];
        return;
    }

    bound.* = util.math.SphereBound.merge(children[0], children[1]);
    for (children[2..]) |csb|
        bound.* = util.math.SphereBound.merge(bound.*, csb);
}
