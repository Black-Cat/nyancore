const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Smooth Union",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    smoothing: f32,

    mats: [2]i32,
    dist_indexes: [2]usize,
    enter_index: usize,
    enter_stack: usize,
};
