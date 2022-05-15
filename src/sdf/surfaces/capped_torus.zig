const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Capped Torus",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
};

pub const Data = struct {
    angle: f32,
    inner_radius: f32,
    outer_radius: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdCappedTorus(in vec3 p, in vec2 sc, in float ra, in float rb){
    \\  p.x = abs(p.x);
    \\  float k = (sc.y*p.x>sc.x*p.y) ? dot(p.xy,sc) : length(p.xy);
    \\  return sqrt(dot(p,p) + ra*ra - 2.*ra*k) - rb;
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdCappedTorus({s}, vec2({d:.5},{d:.5}),{d:.5},{d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        @sin(data.angle),
        @cos(data.angle),
        data.inner_radius,
        data.outer_radius,
    }) catch unreachable;
}
