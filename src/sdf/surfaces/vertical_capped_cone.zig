const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Vertical Capped Cone",
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
    \\float sdVerticalCappedCone(vec3 p, float h, float r1, float r2){
    \\  vec2 q = vec2(length(p.xz),p.y);
    \\  vec2 k1 = vec2(r2, h);
    \\  vec2 k2 = vec2(r2 - r1, 2. * h);
    \\  vec2 ca = vec2(q.x - min(q.x, (q.y<0.)?r1:r2), abs(q.y) - h);
    \\  vec2 cb = q - k1 + k2*clamp(dot(k1-q,k2)/dot2(k2),0.,1.);
    \\  float s = (cb.x<0. && ca.y<0.) ? -1. : 1.;
    \\  return s * sqrt(min(dot2(ca), dot2(cb)));
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdVerticalCappedCone({s},{d:.5},{d:.5},{d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.height,
        data.start_radius,
        data.end_radius,
    }) catch unreachable;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    _ = children;

    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    bound.* = util.math.SphereBound.merge(
        .{
            .pos = .{ 0.0, -data.height, 0.0 },
            .r = data.start_radius,
        },
        .{
            .pos = .{ 0.0, data.height, 0.0 },
            .r = data.end_radius,
        },
    );
}
