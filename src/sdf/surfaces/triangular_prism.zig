const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Triangular Prism",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    height_horizontal: f32,
    height_vertical: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
