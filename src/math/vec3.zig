const math = @import("math.zig");

pub fn zeros() math.vec3 {
    return @splat(0.0);
}

pub fn norm(v: math.vec3) f32 {
    return @sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
}

pub fn normalize(v: math.vec3) math.vec3 {
    const n: f32 = 1.0 / norm(v);
    return v * @as(math.vec3, @splat(n));
}

pub fn cross(a: math.vec3, b: math.vec3) math.vec3 {
    return math.vec3{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    };
}

pub fn dot(a: math.vec3, b: math.vec3) f32 {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

pub fn rotate(v: math.vec3, a: f32, axis: math.vec3) math.vec3 {
    const c: f32 = @cos(a);
    const s: f32 = @sin(a);
    const n: math.vec3 = normalize(axis);

    var t0: math.vec3 = v * @as(math.vec3, @splat(c));
    var t1: math.vec3 = cross(n, v) * @as(math.vec3, @splat(s));
    t0 += t1;

    t1 = n * @as(math.vec3, @splat(dot(n, v) * (1.0 - c)));
    return t0 + t1;
}

pub fn negate(v: math.vec3) math.vec3 {
    return .{ -v[0], -v[1], -v[2] };
}
