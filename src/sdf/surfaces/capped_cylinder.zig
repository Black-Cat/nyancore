const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Capped Cylinder",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = enterCommand,
    .exit_command_fn = exitCommand,
    .append_mat_check_fn = appendMatCheckSurface,
};

pub const Data = struct {
    start: util.math.vec3,
    end: util.math.vec3,
    radius: f32,

    enter_index: usize,
    enter_stack: usize,
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

    const format: []const u8 = "float d{d} = sdCappedCylinder({s}, vec3({d:.5},{d:.5},{d:.5}),vec3({d:.5},{d:.5},{d:.5}),{d:.5});";

    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        data.enter_index,
        ctxt.cur_point_name,
        data.start[0],
        data.start[1],
        data.start[2],
        data.end[0],
        data.end[1],
        data.end[2],
        data.radius,
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
