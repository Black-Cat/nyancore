const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Displacement",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    power: f32,

    enter_index: usize,
    enter_stack: usize,
};
