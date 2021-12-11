const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Rounding",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    radius: f32,

    enter_index: usize,
    enter_stack: usize,
};
