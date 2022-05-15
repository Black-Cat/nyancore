const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Custom Node",
    .data_size = @sizeOf(Data),

    .function_definition = "",
    .enter_command_fn = enterCommand,
    .exit_command_fn = exitCommand,
};

pub const Data = struct {
    pub const max_func_len: usize = 1024;
    enter_function: [max_func_len]u8,
    exit_function: [max_func_len]u8,
};

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const next_point: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, "p{d}", .{iter}) catch unreachable;

    const format: []const u8 = "cpin = {s}; {{ {s} }} vec3 {s} = cpout;";
    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        ctxt.cur_point_name,
        @ptrCast([*c]const u8, &data.enter_function),
        next_point,
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

    const format: []const u8 = "cdin = d{d}; cpin = {s}; {{ {s} }} float d{d} = cdout;";
    const broken_stack: []const u8 = "float d{d} = 1e10;";

    var res: []const u8 = undefined;
    if (ei.enter_index == ctxt.last_value_set_index) {
        res = util.std.fmt.allocPrint(ctxt.allocator, broken_stack, .{ei.enter_index}) catch unreachable;
    } else {
        res = util.std.fmt.allocPrint(ctxt.allocator, format, .{
            ctxt.last_value_set_index,
            ctxt.cur_point_name,
            @ptrCast([*c]const u8, &data.exit_function),
            ei.enter_index,
        }) catch unreachable;
    }

    ctxt.dropPreviousValueIndexes(ei.enter_stack);

    return res;
}
