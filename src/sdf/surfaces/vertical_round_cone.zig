const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Vertical Round Cone",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {
    height: f32,
    start_radius: f32,
    end_radius: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdVerticalRoundCone(vec3 p, float r1, float r2, float h){
    \\  vec2 q = vec2(length(p.xz), p.y);
    \\  float b = (r1-r2)/h;
    \\  float a = sqrt(1.-b*b);
    \\  float k = dot(q,vec2(-b,a));
    \\  if (k < 0.) return length(q) - r1;
    \\  if (k > a*h) return length(q-vec2(0.,h)) - r2;
    \\  return dot(q, vec2(a, b)) - r1;
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdVerticalRoundCone({s},{d:.5},{d:.5},{d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.start_radius,
        data.end_radius,
        data.height,
    }) catch unreachable;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    _ = children;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    bound.* = util.math.SphereBound.merge(
        .{
            .pos = .{ 0.0, 0.0, 0.0 },
            .r = data.start_radius,
        },
        .{
            .pos = .{ 0.0, data.height, 0.0 },
            .r = data.end_radius,
        },
    );
}
