const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Ellipsoid",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    radius: [3]f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
