const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Infinite Cone",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
};

pub const Data = struct {
    angle: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdInfiniteCone(vec3 p, vec2 c) {
    \\  vec2 q = vec2(length(p.xz), -p.y);
    \\  float d = length(q-c*max(dot(q,c),0.));
    \\  return d * ((q.x*c.y-q.y*c.x<0.)?-1.:1.);
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdInfiniteCone({s}, vec2({d:.5},{d:.5}));";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        @sin(data.angle),
        @cos(data.angle),
    }) catch unreachable;
}
