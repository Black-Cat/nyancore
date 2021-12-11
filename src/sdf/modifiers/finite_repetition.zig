const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Finite Repetition",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    period: f32,
    size: [3]f32,
};
