const std = @import("std");

usingnamespace @import("types.zig");
usingnamespace @import("math.zig");

pub fn identity() mat4x4 {
    const zero: f32 = 0.0;
    var m: mat4x4 = .{@splat(4, zero)} ** 4;
    m[0][0] = 1.0;
    m[1][1] = 1.0;
    m[2][2] = 1.0;
    m[3][3] = 1.0;
    return m;
}

pub fn mul(a: mat4x4, b: mat4x4) mat4x4 {
    var vs: mat4x4 = undefined;
    for (vs) |*v, i|
        v.* = @splat(4, b[i][0]) * a[0];

    for (vs) |*v, i|
        v.* = @mulAdd(vec4, @splat(4, b[i][1]), a[1], v.*);

    for (vs) |*v, i|
        v.* = @mulAdd(vec4, @splat(4, b[i][2]), a[2], v.*);

    vs[3] = @mulAdd(vec4, @splat(4, b[3][3]), a[3], vs[3]);

    return vs;
}

pub fn mulv(a: mat4x4, b: vec4) vec4 {
    return a[0] * @splat(4, b[0]) + a[1] * @splat(4, b[1]) + a[2] * @splat(4, b[2]) + a[3] * @splat(4, b[3]);
}

// Doesn't change a's translation row
pub inline fn mulRotOnly(a: mat4x4, b: mat4x4, dest: *mat4x4) void {
    var vs: [3]vec4 = undefined;
    for (vs) |*v, i|
        v.* = @splat(4, b[i][0]) * a[0];

    for (vs) |*v, i|
        v.* = @mulAdd(vec4, @splat(4, b[i][1]), a[1], v.*);

    for (vs) |*v, i|
        v.* = @mulAdd(vec4, @splat(4, b[i][2]), a[2], v.*);

    for (vs) |v, i|
        dest[i] = v;

    dest[3] = a[3];
}

pub fn lookAt(pos: vec3, target: vec3, up: vec3) mat4x4 {
    const f: vec3 = Vec3.normalize(target - pos);
    const s: vec3 = Vec3.normalize(Vec3.cross(up, f));
    const u: vec3 = Vec3.cross(f, s);

    return .{
        .{ s[0], u[0], f[0], 0.0 },
        .{ s[1], u[1], f[1], 0.0 },
        .{ s[2], u[2], f[2], 0.0 },
        .{
            -Vec3.dot(s, pos),
            -Vec3.dot(u, pos),
            -Vec3.dot(f, pos),
            1.0,
        },
    };
}

pub fn perspective(fov_y: f32, aspect: f32, near: f32, far: f32) mat4x4 {
    var res: mat4x4 = .{vec4{ 0.0, 0.0, 0.0, 0.0 }} ** 4;

    const f: f32 = 1.0 / std.math.tan(fov_y * 0.5);
    const depth: f32 = 1.0 / (far - near);

    res[0][0] = f / aspect;
    res[1][1] = f;
    res[2][2] = far * depth;
    res[2][3] = 1.0;
    res[3][2] = -(far * near) * depth;
    return res;
}

pub fn inverse(a: mat4x4) mat4x4 {
    const n0: i32 = ~@as(i32, 0);
    const n1: i32 = ~@as(i32, 1);
    const n2: i32 = ~@as(i32, 2);
    const n3: i32 = ~@as(i32, 3);

    const r0: vec4 = a[0];
    const r1: vec4 = a[1];
    const r2: vec4 = a[2];
    const r3: vec4 = a[3];

    var x0: vec4 = @shuffle(f32, r1, r2, [4]i32{ n3, n3, 3, 3 });
    var x1: vec4 = @shuffle(f32, r2, r3, [4]i32{ n3, n3, n3, 3 });
    var x2: vec4 = @shuffle(f32, r2, r3, [4]i32{ n2, n2, n2, 2 });
    var x3: vec4 = @shuffle(f32, r1, r2, [4]i32{ n2, n2, 2, 2 });

    const t0: vec4 = x3 * x1 - x2 * x0;

    const x4: vec4 = @shuffle(f32, r2, r3, [4]i32{ n1, n1, n1, 1 });
    const x5: vec4 = @shuffle(f32, r1, r2, [4]i32{ n1, n1, 1, 1 });

    const t1: vec4 = x5 * x1 - x4 * x0;
    const t2: vec4 = x5 * x2 - x4 * x3;

    const x6: vec4 = @shuffle(f32, r1, r2, [4]i32{ n0, n0, 0, 0 });
    const x7: vec4 = @shuffle(f32, r2, r3, [4]i32{ n0, n0, n0, 0 });

    const t3: vec4 = x6 * x1 - x7 * x0;
    const t4: vec4 = x6 * x2 - x7 * x3;
    const t5: vec4 = x6 * x4 - x7 * x5;

    x0 = @shuffle(f32, r0, r1, [4]i32{ n0, 0, 0, 0 });
    x1 = @shuffle(f32, r0, r1, [4]i32{ n1, 1, 1, 1 });
    x2 = @shuffle(f32, r0, r1, [4]i32{ n2, 2, 2, 2 });
    x3 = @shuffle(f32, r0, r1, [4]i32{ n3, 3, 3, 3 });

    const v0: vec4 = (x3 * t2 + x1 * t0 - x2 * t1) * vec4{ 1.0, -1.0, 1.0, -1.0 };
    const v1: vec4 = (x3 * t4 + x0 * t0 - x2 * t3) * vec4{ -1.0, 1.0, -1.0, 1.0 };
    const v2: vec4 = (x3 * t5 + x0 * t1 - x1 * t3) * vec4{ 1.0, -1.0, 1.0, -1.0 };
    const v3: vec4 = (x2 * t5 + x0 * t2 - x1 * t4) * vec4{ -1.0, 1.0, -1.0, 1.0 };

    x0 = @shuffle(f32, v0, v1, [4]i32{ 0, 0, n0, n0 });
    x1 = @shuffle(f32, v2, v3, [4]i32{ 0, 0, n0, n0 });
    x0 = @shuffle(f32, x0, x1, [4]i32{ 0, 2, n0, n2 });

    x0 *= r0;
    x0 = @splat(4, 1.0 / @reduce(.Add, x0));

    const res: mat4x4 = .{
        v0 * x0,
        v1 * x0,
        v2 * x0,
        v3 * x0,
    };

    return res;
}

pub fn unprojecti(p: vec3, m: mat4x4, vp: vec4) vec3 {
    var v: vec4 = undefined;
    v[0] = 2.0 * (p[0] - vp[0]) / vp[2] - 1.0;
    v[1] = 2.0 * (p[1] - vp[1]) / vp[3] - 1.0;
    v[2] = p[2];
    v[3] = 1.0;

    v[1] *= -1.0;

    v = mulv(m, v);
    v *= @splat(4, 1.0 / v[3]);
    return .{ v[0], v[1], v[2] };
}

pub fn unproject(p: vec3, m: mat4x4, vp: vec4) vec3 {
    const inv: mat4x4 = inverse(m);
    return unprojecti(p, inv, vp);
}
