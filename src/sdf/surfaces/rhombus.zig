const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Rhombus",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    length_horizontal: f32,
    length_vertical: f32,
    height: f32,
    radius: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
