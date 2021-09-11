usingnamespace @import("types.zig");

pub fn identity() mat4x4 {
    const zero: f32 = 0.0;
    var m: mat4x4 = .{@splat(4, zero)} ** 4;
    m[0][0] = 1.0;
    m[1][1] = 1.0;
    m[2][2] = 1.0;
    m[3][3] = 1.0;
    return m;
}

pub inline fn mul(a: mat4x4, b: mat4x4, dest: mat4x4) void {
    var vs: [4]vec4 = undefined;
    for (vs) |*v, i|
        v.* = @splat(4, b[i][0]) * a[0];

    for (vs) |*v, i|
        v.* = @mulAdd(vec4, @splat(4, b[i][1]), a[1], v);

    for (vs) |*v, i|
        v.* = @mulAdd(vec4, @splat(4, b[i][2]), a[2], v);

    vs[3] = @mulAdd(vec4, @splat(4, b[3][3]), a[3], vs[3]);

    for (vs) |v, i|
        dest[i] = v;
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
