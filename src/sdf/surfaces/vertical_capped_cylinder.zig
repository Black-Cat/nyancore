const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Vertical Capped Cylinder",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    height: f32,
    radius: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
