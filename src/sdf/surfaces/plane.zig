const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Plane",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    normal: [3]f32,
    offset: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
