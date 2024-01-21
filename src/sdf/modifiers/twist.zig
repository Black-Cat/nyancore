const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Twist",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = enterCommand,
    .exit_command_fn = exitCommand,
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {
    power: f32,
};

const function_definition: []const u8 =
    \\vec3 opTwist(vec3 p, float k){
    \\  float c = cos(k*p.y);
    \\  float s = sin(k*p.y);
    \\  mat2 m = mat2(c, -s, s, c);
    \\  vec3 q = vec3(m * p.xz, p.y);
    \\  return q;
    \\}
    \\
;

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;

    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    const next_point: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, "p{d}", .{iter}) catch unreachable;

    const format: []const u8 = "vec3 {s} = opTwist({s}, {d:.5});";
    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{ next_point, ctxt.cur_point_name, data.power }) catch unreachable;

    ctxt.pushPointName(next_point);

    return res;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;
    _ = buffer;

    ctxt.popPointName();
    return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    _ = buffer;

    bound.* = children[0];
}
