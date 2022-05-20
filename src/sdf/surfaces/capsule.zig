const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Capsule",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {
    start: util.math.vec3,
    end: util.math.vec3,
    radius: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdCapsule(vec3 p, vec3 a, vec3 b, float r){
    \\  vec3 pa = p - a;
    \\  vec3 ba = b - a;
    \\  float h = clamp(dot(pa,ba)/dot(ba,ba),0.,1.);
    \\  return length(pa - ba * h) - r;
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdCapsule({s}, vec3({d:.5},{d:.5},{d:.5}),vec3({d:.5},{d:.5},{d:.5}),{d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.start[0],
        data.start[1],
        data.start[2],
        data.end[0],
        data.end[1],
        data.end[2],
        data.radius,
    }) catch unreachable;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    _ = children;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    bound.* = util.math.SphereBound.merge(
        .{
            .pos = data.start,
            .r = data.radius,
        },
        .{
            .pos = data.end,
            .r = data.radius,
        },
    );
}
