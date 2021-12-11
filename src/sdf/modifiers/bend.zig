const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Bend",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    power: f32,
};