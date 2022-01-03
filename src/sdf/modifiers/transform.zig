const SdfInfo = @import("../sdf_info.zig").SdfInfo;
const math = @import("../../math/math.zig");

pub const info: SdfInfo = .{
    .name = "Transform",
    .data_size = @sizeOf(Data),
};

pub const Data = struct {
    rotation: math.vec3,
    translation: math.vec3,
    transform_matrix: math.mat4x4,
};
