const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Infinite Cylinder",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
};

pub const Data = struct {
    direction: [3]f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdInfiniteCylinder(vec3 p, vec3 c){
    \\  return length(p.xz-c.xy)-c.z;
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdInfiniteCylinder({s}, vec3({d:.5},{d:.5},{d:.5}));";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.direction[0],
        data.direction[1],
        data.direction[2],
    }) catch unreachable;
}
