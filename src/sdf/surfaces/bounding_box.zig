const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Bounding Box",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
};

pub const Data = struct {
    size: [3]f32,
    extent: f32,

    mat: usize,
};

const function_definition: []const u8 =
    \\float sdBoundingBox(vec3 p, vec3 b, float e){
    \\  p = abs(p) - b - e;
    \\  vec3 q = abs(p + e) - e;
    \\  return min(min(
    \\    length(max(vec3(p.x,q.y,q.z),0.))+min(max(p.x,max(q.y,q.z)),0.),
    \\    length(max(vec3(q.x,p.y,q.z),0.))+min(max(q.x,max(p.y,q.z)),0.)),
    \\    length(max(vec3(q.x,q.y,p.z),0.))+min(max(q.x,max(q.y,p.z)),0.));
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdBoundingBox({s}, vec3({d:.5},{d:.5},{d:.5}),{d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.size[0],
        data.size[1],
        data.size[2],
        data.extent,
    }) catch unreachable;
}
