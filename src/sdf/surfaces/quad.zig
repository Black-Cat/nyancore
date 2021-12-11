const SdfInfo = @import("../sdf_info.zig").SdfInfo;
usingnamespace @import("../../math/math.zig");

pub const info: SdfInfo = .{
    .name = "Quad",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    point_a: vec3,
    point_b: vec3,
    point_c: vec3,
    point_d: vec3,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
