const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Hexagonal Prism",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
};

pub const Data = struct {
    radius: f32,
    height: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdHexagonalPrism(vec3 p, vec2 h){
    \\  const vec2 k = vec2(-.8660254,.5);
    \\  p = abs(p);
    \\  p.xz -= 2.0 * min(dot(k.xy, p.xz), 0.)*k.xy;
    \\  vec2 d = vec2(length(p.xz-vec2(clamp(p.x,-.5*h.x,.5*h.x),h.x*-k.x))*sign(p.z-h.x*-k.x),p.y-h.y);
    \\  return min(max(d.x,d.y),0.) + length(max(d,0.));
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdHexagonalPrism({s}, vec2({d:.5},{d:.5}));";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.radius,
        data.height,
    }) catch unreachable;
}
