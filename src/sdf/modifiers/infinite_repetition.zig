const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Infinite Repetition",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    period: f32,
};
