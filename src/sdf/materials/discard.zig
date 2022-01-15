const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Discard",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {};
