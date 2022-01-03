const SdfInfo = @import("../sdf_info.zig").SdfInfo;
const math = @import("../../math/math.zig");

pub const info: SdfInfo = .{
    .name = "Triangle",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    point_a: math.vec3,
    point_b: math.vec3,
    point_c: math.vec3,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
