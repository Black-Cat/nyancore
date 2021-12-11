const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Solid Angle",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    angle: f32,
    radius: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
