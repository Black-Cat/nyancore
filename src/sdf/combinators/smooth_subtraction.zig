const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Smooth Subtraction",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = enterCommand,
    .exit_command_fn = exitCommand,
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {
    smoothing: f32,
};

const function_definition: []const u8 =
    \\float opSmoothSubtraction(float d1, float d2, float k){
    \\  float h = clamp(.5 - .5 * (d2 + d1) / k, 0., 1.);
    \\  return mix(d1, -d2, h) + k * h * (1. - h);
    \\}
    \\
;

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;
    _ = buffer;

    ctxt.pushEnterInfo(iter);
    ctxt.pushStackInfo(iter, 0);

    return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));
    const ei: util.EnterInfo = ctxt.popEnterInfo();

    const command: []const u8 = "d{d} = opSmoothSubtraction(d{d}, d{d}, {d:.5});";
    const res: []const u8 = util.smoothCombinatorExitCommand(command, ei.enter_stack, ei.enter_index, ctxt, data.smoothing);

    ctxt.dropPreviousValueIndexes(ei.enter_stack);

    return res;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    _ = buffer;

    bound.* = children[0];
    for (children[1..]) |csb|
        bound.* = util.math.SphereBound.subtract(bound.*, csb);
}
