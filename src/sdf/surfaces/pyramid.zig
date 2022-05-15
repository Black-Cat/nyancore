const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Pyramid",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
};

pub const Data = struct {
    height: f32,

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

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdPyramid({s},{d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.height,
    }) catch unreachable;
}
