const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Solid Angle",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {
    angle: f32,
    radius: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdSolidAngle(vec3 p, vec2 c, float ra){
    \\  vec2 q = vec2(length(p.xz),p.y);
    \\  float l = length(q)-ra;
    \\  float m = length(q - c*clamp(dot(q,c),0.,ra));
    \\  return max(l,m*sign(c.y*q.x-c.x*q.y));
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdSolidAngle({s},vec2({d:.5},{d:.5}),{d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        @sin(data.angle),
        @cos(data.angle),
        data.radius,
    }) catch unreachable;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    _ = children;

    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    bound.* = .{
        .pos = util.math.Vec3.zeros(),
        .r = data.radius,
    };
}
