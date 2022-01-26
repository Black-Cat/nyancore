const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Capped Cone",
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
    \\float sdCappedCone(vec3 p, vec3 a, vec3 b, float ra, float rb){
    \\  float rba = rb - ra;
    \\  float baba = dot(b-a,b-a);
    \\  float papa = dot(p-a,p-a);
    \\  float paba = dot(p-a,b-a)/baba;
    \\  float x = sqrt(papa - paba*paba*baba);
    \\  float cax = max(0.,x-((paba<.5)?ra:rb));
    \\  float cay = abs(paba-.5)-.5;
    \\  float k = rba*rba + baba;
    \\  float f = clamp((rba*(x-ra)+paba*baba)/k,0.,1.);
    \\  float cbx = x-ra-f*rba;
    \\  float cby = paba - f;
    \\  float s = (cbx < 0. && cay < 0.) ? -1. : 1.;
    \\  return s * sqrt(min(cax*cax + cay*cay*baba, cbx*cbx + cby*cby*baba));
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

    const format: []const u8 = "float d{d} = sdCappedCone({s}, vec3({d:.5},{d:.5},{d:.5}),vec3({d:.5},{d:.5},{d:.5}),{d:.5},{d:.5});";

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
