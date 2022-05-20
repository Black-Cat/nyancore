const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Triangle",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {
    point_a: util.math.vec3,
    point_b: util.math.vec3,
    point_c: util.math.vec3,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdTriangle(vec3 p, vec3 a, vec3 b, vec3 c){
    \\  vec3 ba = b - a; vec3 pa = p - a;
    \\  vec3 cb = c - b; vec3 pb = p - b;
    \\  vec3 ac = a - c; vec3 pc = p - c;
    \\  vec3 nor = cross(ba, ac);
    \\
    \\  return sqrt(
    \\    (sign(dot(cross(ba,nor),pa)) +
    \\    sign(dot(cross(cb,nor),pb)) +
    \\    sign(dot(cross(ac,nor),pc))<2.)
    \\    ?
    \\    min(min(
    \\    dot2(ba*clamp(dot(ba,pa)/dot2(ba),0.,1.)-pa),
    \\    dot2(cb*clamp(dot(cb,pb)/dot2(cb),0.,1.)-pb)),
    \\    dot2(ac*clamp(dot(ac,pc)/dot2(ac),0.,1.)-pc))
    \\    :
    \\    dot(nor,pa)*dot(nor,pa)/dot2(nor));
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdTriangle({s},vec3({d:.5},{d:.5},{d:.5}),vec3({d:.5},{d:.5},{d:.5}),vec3({d:.5},{d:.5},{d:.5}));";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.point_a[0],
        data.point_a[1],
        data.point_a[2],
        data.point_b[0],
        data.point_b[1],
        data.point_b[2],
        data.point_c[0],
        data.point_c[1],
        data.point_c[2],
    }) catch unreachable;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    _ = children;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    bound.* = util.math.SphereBound.from3Points(data.point_a, data.point_b, data.point_c);
}
