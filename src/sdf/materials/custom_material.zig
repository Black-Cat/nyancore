const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Custom Material",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    pub const max_func_len: usize = 1024;
    material_function: [max_func_len]u8,
};
