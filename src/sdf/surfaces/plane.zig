const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Plane",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
};

pub const Data = struct {
    normal: [3]f32,
    offset: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdPlane(vec3 p, vec3 n, float h){
    \\  return dot(p,n) + h;
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdPlane({s},vec3({d:.5},{d:.5},{d:.5}),{d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.normal[0],
        data.normal[1],
        data.normal[2],
        data.offset,
    }) catch unreachable;
}
