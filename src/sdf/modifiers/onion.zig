const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Onion",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    thickness: f32,

    enter_index: usize,
    enter_stack: usize,
};
