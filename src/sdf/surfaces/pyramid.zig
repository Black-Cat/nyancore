const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Pyramid",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = enterCommand,
    .exit_command_fn = exitCommand,
    .append_mat_check_fn = appendMatCheckSurface,
};

pub const Data = struct {
    height: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};

const function_definition: []const u8 =
    \\float sdPyramid(vec3 p, float h){
    \\  float m2 = h*h + .25;
    \\  p.xz = abs(p.xz);
    \\  p.xz = (p.z>p.x)?p.zx:p.xz;
    \\  p.xz -= .5;
    \\  vec3 q = vec3(p.z,h*p.y - .5*p.x, h*p.x + .5*p.y);
    \\  float s = max(-q.x,0.);
    \\  float t = clamp((q.y-.5*p.z)/(m2+.25),0.,1.);
    \\  float a = m2*(q.x+s)*(q.x+s) + q.y*q.y;
    \\  float b = m2*(q.x+.5*t)*(q.x+.5*t) + (q.y-m2*t)*(q.t-m2*t);
    \\  float d2 = min(q.y,-q.x*m2-q.y*.5)>0. ? 0. : min(a,b);
    \\  return sqrt((d2+q.z*q.z)/m2)*sign(max(q.z,-p.y));
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

    const format: []const u8 = "float d{d} = sdPyramid({s},{d:.5});";

    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        data.enter_index,
        ctxt.cur_point_name,
        data.height,
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
