const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Elongate",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    height: f32,
};
