const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Capped Cone",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = util.surfaceEnterCommand(Data),
    .exit_command_fn = util.surfaceExitCommand(Data, exitCommand),
    .append_mat_check_fn = util.surfaceMatCheckCommand(Data),
};

pub const Data = struct {
    start: util.math.vec3,
    end: util.math.vec3,
    start_radius: f32,
    end_radius: f32,

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

fn exitCommand(data: *Data, enter_index: usize, cur_point_name: []const u8, allocator: util.std.mem.Allocator) []const u8 {
    const format: []const u8 = "float d{d} = sdCappedCone({s}, vec3({d:.5},{d:.5},{d:.5}),vec3({d:.5},{d:.5},{d:.5}),{d:.5},{d:.5});";
    return util.std.fmt.allocPrint(allocator, format, .{
        enter_index,
        cur_point_name,
        data.start[0],
        data.start[1],
        data.start[2],
        data.end[0],
        data.end[1],
        data.end[2],
        data.start_radius,
        data.end_radius,
    }) catch unreachable;
}
