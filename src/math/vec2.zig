const math = @import("math.zig");

pub fn dot(a: math.vec2, b: math.vec2) f32 {
    return a[0] * b[0] + a[1] * b[1];
}

pub fn norm2(a: math.vec2) f32 {
    return dot(a, a);
}

pub fn norm(a: math.vec2) f32 {
    return @sqrt(norm2(a));
}
