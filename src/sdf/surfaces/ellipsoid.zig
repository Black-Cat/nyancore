const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Ellipsoid",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {
    radius: [3]f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdEllipsoid(vec3 p, vec3 r){
    \\  float k0 = length(p/r);
    \\  float k1 = length(p/(r*r));
    \\  return k0*(k0-1.)/k1;
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdEllipsoid({s}, vec3({d:.5},{d:.5},{d:.5}));";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.radius[0],
        data.radius[1],
        data.radius[2],
    }) catch unreachable;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    _ = children;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    bound.* = .{
        .pos = util.math.Vec3.zeros(),
        .r = @maximum(data.radius[0], @maximum(data.radius[1], data.radius[2])),
    };
}
