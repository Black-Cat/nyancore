const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Vertical Capsule",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
};

pub const Data = struct {
    height: f32,
    radius: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdVerticalCapsule(vec3 p, float h, float r){
    \\  p.y -= clamp(p.y,0.,h);
    \\  return length(p) - r;
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdVerticalCapsule({s},{d:.5},{d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.height,
        data.radius,
    }) catch unreachable;
}
