const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Discard",
    .data_size = @sizeOf(Data),

    .function_definition = "",
    .enter_command_fn = enterCommand,
};

pub const Data = struct {};

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = iter;
    _ = mat_offset;
    _ = buffer;

    const format: []const u8 = "discard;";

    return util.std.fmt.allocPrint(ctxt.allocator, format, .{}) catch unreachable;
}
