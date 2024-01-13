const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Sphere Bound",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = enterCommand,
    .exit_command_fn = exitCommand,
};

pub const Data = struct {
    bound: util.math.sphereBound,
};

const function_definition: []const u8 =
    \\float utilBound(vec3 p, vec3 c, float r){
    \\  return length(c - p) - r;
    \\}
    \\
;

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;

    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    ctxt.pushEnterInfo(iter);
    ctxt.pushStackInfo(iter, 0);

    const format: []const u8 = "float d{d} = utilBound({s},vec3({d:.5},{d:.5},{d:.5}),{d:.5}); if (d{d} < MAP_EPS * 10.0) {{\n";
    return util.std.fmt.allocPrint(ctxt.allocator, format, .{
        iter,
        ctxt.cur_point_name,
        data.bound.pos[0],
        data.bound.pos[1],
        data.bound.pos[2],
        data.bound.r,
        iter,
    }) catch unreachable;
}

pub fn shadowEnterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;
    _ = buffer;

    const format: []const u8 = "float d{d};{{\n";
    return util.std.fmt.allocPrint(ctxt.allocator, format, .{
        iter,
    }) catch unreachable;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;
    _ = buffer;

    const ei: util.EnterInfo = ctxt.popEnterInfo();

    const format: []const u8 = "d{d} = d{d};}}\n";

    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        ei.enter_index,
        ctxt.last_value_set_index,
    }) catch unreachable;

    ctxt.dropPreviousValueIndexes(ei.enter_stack);

    return res;
}
