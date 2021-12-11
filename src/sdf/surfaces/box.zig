const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Box",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    size: [3]f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
