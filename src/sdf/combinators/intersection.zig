const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Intersection",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    enter_index: usize,
    enter_stack: usize,
};
