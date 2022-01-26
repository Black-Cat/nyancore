const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Round Cone",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = enterCommand,
    .exit_command_fn = exitCommand,
    .append_mat_check_fn = appendMatCheckSurface,
};

pub const Data = struct {
    start: util.math.vec3,
    end: util.math.vec3,
    start_radius: f32,
    end_radius: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};

const function_definition: []const u8 =
    \\float sdRoundCone(vec3 p, vec3 a, vec3 b, float r1, float r2){
    \\  vec3 ba = b - a;
    \\  float l2 = dot(ba,ba);
    \\  float rr = r1 - r2;
    \\  float a2 = l2 - rr*rr;
    \\  float il2 = 1./l2;
    \\
    \\  vec3 pa = p - a;
    \\  float y = dot(pa,ba);
    \\  float z = y - l2;
    \\  float x2 = dot2(pa*l2 - ba*y);
    \\  float y2 = y*y*l2;
    \\  float z2 = z*z*l2;
    \\
    \\  float k = sign(rr)*rr*rr*x2;
    \\  if (sign(z)*a2*z2 > k) return sqrt(x2 + z2) * il2 - r2;
    \\  if (sign(y)*a2*y2 < k) return sqrt(x2 + y2) * il2 - r1;
    \\  return (sqrt(x2*a2*il2)+y*rr)*il2 - r1;
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

    const format: []const u8 = "float d{d} = sdRoundCone({s},vec3({d:.5},{d:.5},{d:.5}),vec3({d:.5},{d:.5},{d:.5}),{d:.5},{d:.5});";

    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        data.enter_index,
        ctxt.cur_point_name,
        data.start[0],
        data.start[1],
        data.start[2],
        data.end[0],
        data.end[1],
        data.end[2],
        data.start_radius,
        data.end_radius,
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
