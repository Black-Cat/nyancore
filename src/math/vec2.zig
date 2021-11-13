usingnamespace @import("types.zig");

pub fn dot(a: vec2, b: vec2) f32 {
    return a[0] * b[0] + a[1] * b[1];
}

pub fn norm2(a: vec2) f32 {
    return dot(a, a);
}
