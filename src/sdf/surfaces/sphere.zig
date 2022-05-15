const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Sphere",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
};

pub const Data = struct {
    radius: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdSphere(vec3 p, float s){
    \\  return length(p) - s;
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdSphere({s},{d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.radius,
    }) catch unreachable;
}
