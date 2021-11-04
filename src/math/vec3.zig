usingnamespace @import("types.zig");

pub fn zeros() vec3 {
    const zero: f32 = 0.0;
    return @splat(3, zero);
}

pub fn norm(v: vec3) f32 {
    return @sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
}

pub fn normalize(v: vec3) vec3 {
    const n: f32 = 1.0 / norm(v);
    return v * @splat(3, n);
}

pub fn cross(a: vec3, b: vec3) vec3 {
    return vec3{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    };
}

pub fn dot(a: vec3, b: vec3) f32 {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

pub fn rotate(v: vec3, a: f32, axis: vec3) vec3 {
    const c: f32 = @cos(a);
    const s: f32 = @sin(a);
    const n: vec3 = normalize(axis);

    var t0: vec3 = v * @splat(3, c);
    var t1: vec3 = cross(n, v) * @splat(3, s);
    t0 += t1;

    t1 = n * @splat(3, dot(n, v) * (1.0 - c));
    return t0 + t1;
}
