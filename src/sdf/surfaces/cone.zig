const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Cone",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    angle: f32,
    height: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
