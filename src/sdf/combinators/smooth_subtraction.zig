const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Smooth Subtraction",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    smoothing: f32,

    enter_index: usize,
    enter_stack: usize,
};
