const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Smooth Intersection",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    smoothing: f32,

    enter_index: usize,
    enter_stack: usize,
};
