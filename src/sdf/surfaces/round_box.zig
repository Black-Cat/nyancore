const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Round Box",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    size: [3]f32,
    radius: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
