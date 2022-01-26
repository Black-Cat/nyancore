const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Subtraction",
    .data_size = @sizeOf(Data),

    .function_definition = "",
    .enter_command_fn = enterCommand,
    .exit_command_fn = exitCommand,
};

pub const Data = struct {
    enter_index: usize,
    enter_stack: usize,
};

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

    const command: []const u8 = "d{d} = max(d{d}, -d{d});";
    const res: []const u8 = util.combinatorExitCommand(command, data.enter_stack, data.enter_index, ctxt);

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}
