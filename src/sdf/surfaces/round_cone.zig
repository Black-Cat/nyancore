const SdfInfo = @import("../sdf_info.zig").SdfInfo;
const math = @import("../../math/math.zig");

pub const info: SdfInfo = .{
    .name = "Round Cone",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    start: math.vec3,
    end: math.vec3,
    start_radius: f32,
    end_radius: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
