const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Octahedron",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {
    radius: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdOctahedron(vec3 p, float s){
    \\  p = abs(p);
    \\  float m = p.x+p.y+p.z-s;
    \\  vec3 q;
    \\  if (3.*p.x < m) q = p.xyz;
    \\  else if (3.*p.y < m) q = p.yzx;
    \\  else if (3.*p.z < m) q = p.zxy;
    \\  else return m*.57735027;
    \\  float k = clamp(.5*(q.z-q.y+s),0.,s);
    \\  return length(vec3(q.x,q.y-s+k,q.z-k));
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdOctahedron({s},{d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.radius,
    }) catch unreachable;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    _ = children;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    bound.* = .{
        .pos = util.math.Vec3.zeros(),
        .r = data.radius,
    };
}
