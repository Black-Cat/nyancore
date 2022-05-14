const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Icosahedron Edges",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = enterCommand,
    .exit_command_fn = exitCommand,
    .append_mat_check_fn = appendMatCheckSurface,
};

pub const Data = struct {
    radius: f32,
    edge_radius: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};

//https://www.shadertoy.com/view/Mly3R3
const function_definition: []const u8 =
    \\float sdIcosahedronEdges(vec3 p, float r, float er){
    \\  const float J = 0.309016994375;
    \\  const float K = J+.5;
    \\  const mat3 R0 = mat3(0.5,-K,J        ,K,J,-0.5                       ,J,0.5,K                          );
    \\  const mat3 R1 = mat3(K,J,-0.5        ,J,0.5,K                        ,0.5,-K,J                         );
    \\  const mat3 R2 = mat3(-J,-0.5,K       ,0.5,-K,-J                      ,K,J,0.5                          );      
    \\  const mat3 R3 = mat3(-0.5,sqrt(.75),0,K,0.467086179481,0.356822089773,-J,-0.178411044887,0.934172358963);
    \\  const float PHI = (1.+sqrt(5.))/2.;
    \\  const float B = 1. / sqrt( 1. + PHI*PHI );
    \\  const vec3 O3 = vec3(B,B/sqrt(3.),sqrt(1.-4./3.*B*B));
    \\  
    \\  p = R0 * abs(p);
    \\  p = R1 * abs(p);
    \\  p = R2 * abs(p);
    \\  p = R3 * abs(p) - O3 * r;
    \\
    \\  return length(vec3(max(p.x, 0.), p.y, p.z)) - er;
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

    const format: []const u8 = "float d{d} = sdIcosahedronEdges({s}, {d:.5}, {d:.5});";

    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        data.enter_index,
        ctxt.cur_point_name,
        data.radius,
        data.edge_radius,
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
