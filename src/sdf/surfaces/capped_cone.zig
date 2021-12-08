usingnamespace @import("../../math/math.zig");

pub const Data = struct {
    start: vec3,
    end: vec3,
    start_radius: f32,
    end_radius: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
