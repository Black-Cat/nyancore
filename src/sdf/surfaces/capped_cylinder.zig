const SdfInfo = @import("../sdf_info.zig").SdfInfo;
usingnamespace @import("../../math/math.zig");

pub const info: SdfInfo = .{
    .name = "Capped Cylinder",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    start: vec3,
    end: vec3,
    radius: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
