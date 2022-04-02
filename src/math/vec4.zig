const math = @import("math.zig");

pub fn zeros() math.vec4 {
    return @splat(4, @as(f32, 0.0));
}

pub fn fromVec3(v: math.vec3, w: f32) math.vec4 {
    return .{ v[0], v[1], v[2], w };
}

pub fn dot(a: math.vec4, b: math.vec4) f32 {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3];
}
