const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Round Cylinder",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
};

pub const Data = struct {
    diameter: f32,
    rounding_radius: f32,
    height: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdRoundedCylinder(vec3 p, float ra, float rb, float h){
    \\  vec2 d = vec2(length(p.xz)-2.*ra+rb, abs(p.y) - h);
    \\  return min(max(d.x,d.y),0.) + length(max(d,0.)) - rb;
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdRoundedCylinder({s},{d:.5},{d:.5},{d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.diameter / 2.0,
        data.rounding_radius,
        data.height,
    }) catch unreachable;
}
