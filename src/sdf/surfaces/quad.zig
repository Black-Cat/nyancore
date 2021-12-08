usingnamespace @import("../../math/math.zig");

pub const Data = struct {
    point_a: vec3,
    point_b: vec3,
    point_c: vec3,
    point_d: vec3,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
