const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Triangular Prism",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {
    height_horizontal: f32,
    height_vertical: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdTriangularPrism(vec3 p, vec2 h){
    \\  vec3 q = abs(p);
    \\  return max(q.z-h.y,max(q.x*.866025+p.y*.5,-p.y)-h.x*.5);
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdTriangularPrism({s},vec2({d:.5},{d:.5}));";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.height_horizontal,
        data.height_vertical,
    }) catch unreachable;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    _ = children;

    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    bound.* = .{
        .pos = util.math.Vec3.zeros(),
        .r = util.math.Vec3.norm(.{ data.height_vertical, data.height_horizontal, 0.0 }),
    };
}
