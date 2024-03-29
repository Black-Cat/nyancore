const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Icosahedron",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {
    radius: f32,
    corner_radius: f32,

    mat: usize,
};

//https://www.shadertoy.com/view/Mly3R3
const function_definition: []const u8 =
    \\float sdIcosahedron(vec3 p, float r, float cr){
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
    \\  return length(vec3(max(p.x, 0.), max(p.y, 0.), p.z)) - cr;
    \\}
    \\
;

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdIcosahedron({s}, {d:.5}, {d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.radius,
        data.corner_radius,
    }) catch unreachable;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    _ = children;

    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    bound.* = .{
        .pos = util.math.Vec3.zeros(),
        .r = data.radius + data.corner_radius,
    };
}
