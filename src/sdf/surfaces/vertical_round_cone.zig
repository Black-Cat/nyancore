const SdfInfo = @import("../sdf_info.zig").SdfInfo;

pub const info: SdfInfo = .{
    .name = "Vertical Round Cone",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    height: f32,
    start_radius: f32,
    end_radius: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
