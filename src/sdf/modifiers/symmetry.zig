const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Symmetry",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    axis: i32,
};
