const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Hexagonal Prism",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    radius: f32,
    height: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
