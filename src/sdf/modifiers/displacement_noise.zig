const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Displacement Noise",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    power: f32,
    scale: f32,

    enter_index: usize,
    enter_stack: usize,
};
