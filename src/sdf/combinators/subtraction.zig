const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Subtraction",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    enter_index: usize,
    enter_stack: usize,
};
