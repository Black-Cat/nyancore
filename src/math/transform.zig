usingnamespace @import("types.zig");
const Mat4x4 = @import("mat4x4.zig");

inline fn rotateTransform(comptime ids: [4][2]usize, rot: f32) mat4x4 {
    var m: mat4x4 = Mat4x4.identity();
    const s: f32 = @sin(rot);
    const c: f32 = @cos(rot);

    m[ids[0][0]][ids[0][1]] = c;
    m[ids[1][0]][ids[1][1]] = s;
    m[ids[2][0]][ids[2][1]] = -s;
    m[ids[3][0]][ids[3][1]] = c;

    return m;
}

pub inline fn rotateX(m: *mat4x4, rot: f32) void {
    const ids: [4][2]usize = [_][2]usize{ .{ 1, 1 }, .{ 1, 2 }, .{ 2, 1 }, .{ 2, 2 } };
    const tr: mat4x4 = rotateTransform(ids, rot);
    Mat4x4.mulRotOnly(m.*, tr, m);
}

pub inline fn rotateY(m: *mat4x4, rot: f32) void {
    const ids: [4][2]usize = [_][2]usize{ .{ 0, 0 }, .{ 2, 0 }, .{ 0, 2 }, .{ 2, 2 } };
    const tr: mat4x4 = rotateTransform(ids, rot);
    Mat4x4.mulRotOnly(m.*, tr, m);
}

pub inline fn rotateZ(m: *mat4x4, rot: f32) void {
    const ids: [4][2]usize = [_][2]usize{ .{ 0, 0 }, .{ 0, 1 }, .{ 1, 0 }, .{ 1, 1 } };
    const tr: mat4x4 = rotateTransform(ids, rot);
    Mat4x4.mulRotOnly(m.*, tr, m);
}

pub inline fn translate(m: *mat4x4, tr: vec3) void {
    m[3] = @mulAdd(vec4, m[0], @splat(4, tr[0]), m[3]);
    m[3] = @mulAdd(vec4, m[1], @splat(4, tr[1]), m[3]);
    m[3] = @mulAdd(vec4, m[2], @splat(4, tr[2]), m[3]);
}
