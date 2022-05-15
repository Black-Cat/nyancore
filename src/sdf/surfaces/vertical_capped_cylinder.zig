const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Vertical Capped Cylinder",
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
    \\float sdVerticalCappedCylinder(vec3 p, float h, float r) {
    \\  vec2 d = abs(vec2(length(p.xz),p.y)) - vec2(r,h);
    \\  return min(max(d.x,d.y),0.) + length(max(d,0.));
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdVerticalCappedCylinder({s},{d:.5},{d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.height,
        data.radius,
    }) catch unreachable;
}
