const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Custom Material",
    .data_size = @sizeOf(Data),

    .function_definition = "",
    .enter_command_fn = enterCommand,
};

pub const Data = struct {
    pub const max_func_len: usize = 1024;
    material_function: [max_func_len]u8,
};

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = iter;
    _ = mat_offset;

    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    return util.std.fmt.allocPrint(ctxt.allocator, "{s}", .{data.material_function}) catch unreachable;
}
