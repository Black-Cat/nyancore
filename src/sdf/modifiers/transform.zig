const SdfInfo = @import("../sdf_info.zig").SdfInfo;
usingnamespace @import("../../math/math.zig");

pub const info: SdfInfo = .{
    .name = "Transform",
    .data_size = @sizeOf(Data),
};

const Data = struct {
    rotation: vec3,
    translation: vec3,
    transform_matrix: mat4x4,
};
