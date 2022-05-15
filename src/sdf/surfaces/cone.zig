const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Cone",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
};

pub const Data = struct {
    angle: f32,
    height: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdCone(vec3 p, vec2 q){
    \\  vec2 w = vec2(length(p.xz), p.y);
    \\  vec2 a = w - q * clamp(dot(w,q)/dot(q,q), 0., 1.);
    \\  vec2 b = w - q * vec2(clamp(w.x/q.x, 0., 1.), 1.);
    \\  float k = sign(q.y);
    \\  float d = min(dot(a,a),dot(b,b));
    \\  float s = max(k * (w.x * q.y - w.y * q.x), k * (w.y - q.y));
    \\  return sqrt(d) * sign(s);
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdCone({s}, vec2({d:.5},{d:.5}));";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.height * (@sin(data.angle) / @cos(data.angle)),
        -data.height,
    }) catch unreachable;
}
