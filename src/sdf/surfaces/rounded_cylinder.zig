const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Round Cylinder",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    diameter: f32,
    rounding_radius: f32,
    height: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
