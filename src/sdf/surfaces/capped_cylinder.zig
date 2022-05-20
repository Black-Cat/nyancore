const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Capped Cylinder",
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
    \\float sdCappedCylinder(vec3 p, vec3 a, vec3 b, float r){
    \\  vec3 ba = b - a;
    \\  vec3 pa = p - a;
    \\  float baba = dot(ba,ba);
    \\  float paba = dot(pa,ba);
    \\  float x = length(pa*baba-ba*paba) - r * baba;
    \\  float y = abs(paba - baba * .5) - baba * .5;
    \\  float x2 = x*x;
    \\  float y2 = y*y*baba;
    \\  float d = (max(x,y)<0.)?-min(x2,y2):(((x>0.)?x2:0.)+((y>0.)?y2:0.));
    \\  return sign(d)*sqrt(abs(d))/baba;
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdCappedCylinder({s}, vec3({d:.5},{d:.5},{d:.5}),vec3({d:.5},{d:.5},{d:.5}),{d:.5});";
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
