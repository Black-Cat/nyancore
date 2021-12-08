usingnamespace @import("../../math/math.zig");

pub const Data = struct {
    rotation: vec3,
    translation: vec3,
    transform_matrix: mat4x4,
};
