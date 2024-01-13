const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Round Box",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {
    size: [3]f32,
    radius: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdRoundBox(vec3 p, vec3 b, float r){
    \\  vec3 q = abs(p) - b;
    \\  return length(max(q,0.)) + min(max(q.x,max(q.y,q.z)),0.) - r;
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdRoundBox({s},vec3({d:.5},{d:.5},{d:.5}),{d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.size[0],
        data.size[1],
        data.size[2],
        data.radius,
    }) catch unreachable;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    _ = children;

    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    bound.* = .{
        .pos = util.math.Vec3.zeros(),
        .r = util.math.Vec3.norm(.{ data.size[0], data.size[1], data.size[2] }) + data.radius,
    };
}
