const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Lambert",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = enterCommand,
};

pub const Data = struct {
    color: [3]f32,
};

const function_definition: []const u8 =
    \\vec3 matLambert(vec3 l, vec3 n, vec3 col){
    \\  float nl = dot(n, l);
    \\  return max(0.,nl) * col;
    \\}
    \\
;

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = iter;
    _ = mat_offset;

    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    const format: []const u8 = "res = matLambert(l,n,vec3({d:.5},{d:.5},{d:.5}));";

    return util.std.fmt.allocPrint(ctxt.allocator, format, .{ data.color[0], data.color[1], data.color[2] }) catch unreachable;
}
