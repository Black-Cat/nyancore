const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Lambert",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    color: [3]f32,
};
