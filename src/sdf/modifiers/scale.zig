const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Scale",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    scale: f32,

    enter_index: usize,
    enter_stack: usize,
};
