const std = @import("std");
const math = @import("math.zig");

pub fn merge(a: math.sphereBound, b: math.sphereBound) math.sphereBound {
    const dist: f32 = math.Vec3.norm(a.pos - b.pos);
    if (dist + a.r <= b.r)
        return b;
    if (dist + b.r <= a.r)
        return a;

    const r: f32 = (a.r + b.r + dist) / 2.0;
    const pos: math.vec3 = a.pos + (b.pos - a.pos) * @as(math.vec3, @splat((r - a.r) / dist));

    return .{ .pos = pos, .r = r };
}

pub fn intersect(a: math.sphereBound, b: math.sphereBound) math.sphereBound {
    const dist: f32 = math.Vec3.norm(a.pos - b.pos);
    if (dist + a.r <= b.r)
        return a;
    if (dist + b.r <= a.r)
        return b;
    if (dist >= a.r + b.r)
        return .{ .pos = math.Vec3.zeros(), .r = 0.0 };

    var inter_c: math.vec3 = (a.pos + b.pos) * @as(math.vec3, @splat(@as(f32, 0.5)));
    inter_c += @as(math.vec3, @splat((a.r * a.r - b.r * b.r) / (2 * dist * dist))) * (b.pos - a.pos);
    const offset: math.vec3 = (b.pos - a.pos) * @as(math.vec3, @splat(0.5 * std.math.sqrt(2 * (a.r * a.r + b.r * b.r) / (dist * dist) - (std.math.pow(f32, a.r * a.r - b.r * b.r, 2) / std.math.pow(f32, dist, 4)) - 1)));

    return .{
        .pos = inter_c,
        .r = math.Vec3.norm(offset),
    };
}

pub fn subtract(a: math.sphereBound, b: math.sphereBound) math.sphereBound {
    const dist: f32 = math.Vec3.norm(a.pos - b.pos);
    if (dist + a.r <= b.r)
        return b;
    if (dist + b.r <= a.r)
        return a;

    var inter_c: math.vec3 = (a.pos + b.pos) * @as(math.vec3, @splat(@as(f32, 0.5)));
    inter_c += @as(math.vec3, @splat((a.r * a.r - b.r * b.r) / (2 * dist * dist))) * (b.pos - a.pos);
    const offset: math.vec3 = (b.pos - a.pos) * @as(math.vec3, @splat(0.5 * std.math.sqrt(2 * (a.r * a.r + b.r * b.r) / (dist * dist) - (std.math.pow(f32, a.r * a.r - b.r * b.r, 2) / std.math.pow(f32, dist, 4)) - 1)));

    return .{
        .pos = inter_c,
        .r = @max(math.Vec3.norm(offset), math.Vec3.norm(inter_c - a.pos) + a.r),
    };
}

pub fn from3Points(p0: math.vec3, p1: math.vec3, p2: math.vec3) math.sphereBound {
    const a: math.vec3 = p2 - p1;
    const b: math.vec3 = p0 - p2;
    const c: math.vec3 = p1 - p0;

    const u: f32 = math.Vec3.dot(a, a) * math.Vec3.dot(c, b);
    const v: f32 = math.Vec3.dot(b, b) * math.Vec3.dot(c, a);
    const w: f32 = math.Vec3.dot(c, c) * math.Vec3.dot(b, a);

    const pos: math.vec3 = (p0 * @as(math.vec3, @splat(u)) + p1 * @as(math.vec3, @splat(v)) + p2 * @as(math.vec3, @splat(w))) / @as(math.vec3, @splat(u + v + w));

    return .{
        .pos = pos,
        .r = math.Vec3.norm(p0 - pos),
    };
}
