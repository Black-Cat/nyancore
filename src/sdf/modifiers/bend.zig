const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Bend",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    power: f32,
};
