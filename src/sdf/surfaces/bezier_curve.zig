const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Bezier Curve",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = enterCommand,
    .exit_command_fn = exitCommand,
    .append_mat_check_fn = appendMatCheckSurface,
};

pub const Data = struct {
    point_a: util.math.vec3,
    point_b: util.math.vec3,
    point_c: util.math.vec3,
    width_start: f32,
    width_end: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};

// http://research.microsoft.com/en-us/um/people/hoppe/ravg.pdf
const function_definition: []const u8 =
    \\vec3 sdBezierGetClosest(vec2 b0, vec2 b1, vec2 b2) {
    \\  float a = det(b0, b2);
    \\  float b = 2.0 * det(b1, b0);
    \\  float d = 2.0 * det(b2, b1);
    \\  float f = b * d - a * a;
    \\  vec2 d21 = b2 - b1;
    \\  vec2 d10 = b1 - b0;
    \\  vec2 d20 = b2 - b0;
    \\  vec2 gf = 2.0 * (b * d21 + d * d10 + a * d20);
    \\  gf = vec2(gf.y, -gf.x);
    \\  vec2 pp = -f * gf / dot(gf, gf);
    \\  vec2 d0p = b0 - pp;
    \\  float ap = det(d0p, d20);
    \\  float bp = 2.0 * det(d10, d0p);
    \\  float t = clamp((ap + bp) / (2.0 * a + b + d), 0.0, 1.0);
    \\  return vec3(mix(mix(b0, b1, t), mix(b1, b2, t), t), t);
    \\}
    \\
    \\float sdBezier(vec3 p, vec3 a, vec3 b, vec3 c, float w0, float wd){
    \\  vec3 w = normalize(cross(c - b, a - b));
    \\  vec3 u = normalize(c - b);
    \\  vec3 v = normalize(cross(w, u));
    \\
    \\  vec2 a2 = vec2(dot(a - b, u), dot(a - b, v));
    \\  vec2 b2 = vec2(0.0);
    \\  vec2 c2 = vec2(dot(c - b, u), dot(c - b, v));
    \\  vec3 p3 = vec3(dot(p - b, u), dot(p - b, v), dot(p - b, w));
    \\
    \\  vec3 cp = sdBezierGetClosest(a2 - p3.xy, b2 - p3.xy, c2 - p3.xy);
    \\
    \\  return sqrt(dot(cp.xy, cp.xy) + p3.z * p3.z) - (w0 + wd * cp.z);
    \\}
    \\
;

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    data.enter_index = iter;
    data.enter_stack = ctxt.value_indexes.items.len;
    ctxt.pushStackInfo(iter, @intCast(i32, data.mat + mat_offset));

    return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const format: []const u8 = "float d{d} = sdBezier({s}, vec3({d:.5},{d:.5},{d:.5}), vec3({d:.5},{d:.5},{d:.5}), vec3({d:.5},{d:.5},{d:.5}), {d:.5}, {d:.5});";

    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        data.enter_index,
        ctxt.cur_point_name,
        data.point_a[0],
        data.point_a[1],
        data.point_a[2],
        data.point_b[0],
        data.point_b[1],
        data.point_b[2],
        data.point_c[0],
        data.point_c[1],
        data.point_c[2],
        data.width_start,
        data.width_end - data.width_start,
    }) catch unreachable;

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}

fn appendMatCheckSurface(exit_command: []const u8, buffer: *[]u8, mat_offset: usize, allocator: util.std.mem.Allocator) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const format: []const u8 = "{s}if(d{d}<MAP_EPS)return matToColor({d}.,l,n,v);";
    return util.std.fmt.allocPrint(allocator, format, .{
        exit_command,
        data.enter_index,
        data.mat + mat_offset,
    }) catch unreachable;
}
