const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Infinite Repetition",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    period: f32,
};
