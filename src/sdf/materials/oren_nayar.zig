const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Oren Nayar",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    color: [3]f32,
    roughness: f32,
};
