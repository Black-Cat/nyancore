const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Round Cone",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
};

pub const Data = struct {
    start: util.math.vec3,
    end: util.math.vec3,
    start_radius: f32,
    end_radius: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdRoundCone(vec3 p, vec3 a, vec3 b, float r1, float r2){
    \\  vec3 ba = b - a;
    \\  float l2 = dot(ba,ba);
    \\  float rr = r1 - r2;
    \\  float a2 = l2 - rr*rr;
    \\  float il2 = 1./l2;
    \\
    \\  vec3 pa = p - a;
    \\  float y = dot(pa,ba);
    \\  float z = y - l2;
    \\  float x2 = dot2(pa*l2 - ba*y);
    \\  float y2 = y*y*l2;
    \\  float z2 = z*z*l2;
    \\
    \\  float k = sign(rr)*rr*rr*x2;
    \\  if (sign(z)*a2*z2 > k) return sqrt(x2 + z2) * il2 - r2;
    \\  if (sign(y)*a2*y2 < k) return sqrt(x2 + y2) * il2 - r1;
    \\  return (sqrt(x2*a2*il2)+y*rr)*il2 - r1;
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdRoundCone({s},vec3({d:.5},{d:.5},{d:.5}),vec3({d:.5},{d:.5},{d:.5}),{d:.5},{d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.start[0],
        data.start[1],
        data.start[2],
        data.end[0],
        data.end[1],
        data.end[2],
        data.start_radius,
        data.end_radius,
    }) catch unreachable;
}
