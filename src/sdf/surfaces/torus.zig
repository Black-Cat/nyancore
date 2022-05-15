const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Torus",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
};

pub const Data = struct {
    inner_radius: f32,
    outer_radius: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdTorus(vec3 p, vec2 t){
    \\  vec2 q = vec2(length(p.xz)-t.x,p.y);
    \\  return length(q)-t.y;
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdTorus({s},vec2({d:.5},{d:.5}));";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.inner_radius,
        data.outer_radius,
    }) catch unreachable;
}
