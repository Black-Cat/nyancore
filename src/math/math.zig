const std = @import("std");

pub const vec2 = @Vector(2, f32);
pub const vec3 = @Vector(3, f32);
pub const vec4 = @Vector(4, f32);

pub const mat4x4 = [4]vec4;
pub const mat2x2 = [2]vec2;

pub const ray = struct {
    pos: vec3,
    dir: vec3,
};

pub const sphereBound = struct {
    pos: vec3,
    r: f32,
};

pub const Vec2 = @import("vec2.zig");
pub const Vec3 = @import("vec3.zig");
pub const Vec4 = @import("vec4.zig");
pub const Mat4x4 = @import("mat4x4.zig");
pub const Mat2x2 = @import("mat2x2.zig");
pub const Ray = @import("ray.zig");
pub const SphereBound = @import("sphere_bound.zig");
pub const Transform = @import("transform.zig");

pub fn rad(deg: f32) f32 {
    return deg * std.math.pi / 180.0;
}

pub fn clamp(v: f32, lower: f32, upper: f32) f32 {
    return @min(@max(v, lower), upper);
}

pub fn clamp_zo(v: f32) f32 {
    return clamp(v, 0.0, 1.0);
}
