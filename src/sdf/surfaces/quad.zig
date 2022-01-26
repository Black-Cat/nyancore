const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Quad",
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
    point_d: util.math.vec3,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};

const function_definition: []const u8 =
    \\float sdQuad(vec3 p, vec3 a, vec3 b, vec3 c, vec3 d){
    \\  vec3 ba = b - a; vec3 pa = p - a;
    \\  vec3 cb = c - b; vec3 pb = p - b;
    \\  vec3 dc = d - c; vec3 pc = p - c;
    \\  vec3 ad = a - d; vec3 pd = p - d;
    \\  vec3 nor = cross(ba, ad);
    \\  return sqrt(
    \\    (sign(dot(cross(ba,nor),pa)) +
    \\    sign(dot(cross(cb,nor),pb)) +
    \\    sign(dot(cross(dc,nor),pc)) +
    \\    sign(dot(cross(ad,nor),pd))<3.)
    \\    ?
    \\    min(min(min(
    \\    dot2(ba*clamp(dot(ba,pa)/dot2(ba),0.,1.)-pa),
    \\    dot2(cb*clamp(dot(cb,pb)/dot2(cb),0.,1.)-pb)),
    \\    dot2(dc*clamp(dot(dc,pc)/dot2(dc),0.,1.)-pc)),
    \\    dot2(ad*clamp(dot(ad,pd)/dot2(ad),0.,1.)-pd))
    \\    :
    \\    dot(nor,pa)*dot(nor,pa)/dot2(nor));
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

    const format: []const u8 = "float d{d} = sdQuad({s},vec3({d:.5},{d:.5},{d:.5}),vec3({d:.5},{d:.5},{d:.5}),vec3({d:.5},{d:.5},{d:.5}),vec3({d:.5},{d:.5},{d:.5}));";

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
        data.point_d[0],
        data.point_d[1],
        data.point_d[2],
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
