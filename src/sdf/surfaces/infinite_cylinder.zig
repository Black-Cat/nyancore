const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Infinite Cylinder",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    direction: [3]f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
