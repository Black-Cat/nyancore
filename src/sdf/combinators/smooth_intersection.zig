const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Smooth Intersection",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = enterCommand,
    .exit_command_fn = exitCommand,
};

pub const Data = struct {
    smoothing: f32,

    enter_index: usize,
    enter_stack: usize,
};

const function_definition: []const u8 =
    \\float opSmoothIntersection(float d1, float d2, float k){
    \\  float h = clamp(.5 - .5 * (d2 - d1) / k, 0., 1.);
    \\  return mix(d2, d1, h) + k * h * (1. - h);
    \\}
    \\
;

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    data.enter_index = iter;
    data.enter_stack = ctxt.value_indexes.items.len;
    ctxt.pushStackInfo(iter, 0);

    return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const command: []const u8 = "d{d} = opSmoothIntersection(d{d}, d{d}, {d:.5});";
    const res: []const u8 = util.smoothCombinatorExitCommand(command, data.enter_stack, data.enter_index, ctxt, data.smoothing);

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}
