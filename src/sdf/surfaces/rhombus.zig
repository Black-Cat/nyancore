const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Rhombus",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {
    length_horizontal: f32,
    length_vertical: f32,
    height: f32,
    radius: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdRhombus(vec3 p, float la, float lb, float h, float ra){
    \\  p = abs(p);
    \\  vec2 b = vec2(la, lb);
    \\  float f = clamp((ndot(b,b-2.*p.xz))/dot(b,b),-1.,1.);
    \\  vec2 q = vec2(length(p.xz-.5*b*vec2(1.-f,1.+f))*sign(p.x*b.y+p.z*b.x-b.x*b.y)-ra, p.y-h);
    \\  return min(max(q.x,q.y),0.) + length(max(q,0.));
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdRhombus({s},{d:.5},{d:.5},{d:.5},{d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.length_horizontal,
        data.length_vertical,
        data.height,
        data.radius,
    }) catch unreachable;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    _ = children;

    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    const hor_radius: f32 = @max(data.length_horizontal, data.length_vertical) + data.radius;

    bound.* = .{
        .pos = util.math.Vec3.zeros(),
        .r = util.math.Vec3.norm(.{ hor_radius, data.height, 0.0 }),
    };
}
