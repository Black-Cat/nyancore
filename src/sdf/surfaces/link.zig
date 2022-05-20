const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Link",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {
    length: f32,
    inner_radius: f32,
    outer_radius: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdLink(vec3 p, float le, float r1, float r2){
    \\  vec3 q = vec3(p.x, max(abs(p.y)-le,0.),p.z);
    \\  return length(vec2(length(q.xy)-r1,q.z)) - r2;
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdLink({s},{d:.5},{d:.5},{d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.length,
        data.inner_radius,
        data.outer_radius,
    }) catch unreachable;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    _ = children;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    bound.* = .{
        .pos = util.math.Vec3.zeros(),
        .r = data.length + data.outer_radius + data.inner_radius,
    };
}
