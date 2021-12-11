const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Twist",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    power: f32,
};
