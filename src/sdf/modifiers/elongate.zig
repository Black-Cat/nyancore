const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Elongate",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    height: f32,
};
