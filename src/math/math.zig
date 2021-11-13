const std = @import("std");

pub usingnamespace @import("types.zig");

pub const Vec2 = @import("vec2.zig");
pub const Vec3 = @import("vec3.zig");
pub const Vec4 = @import("vec4.zig");
pub const Mat4x4 = @import("mat4x4.zig");
pub const Mat2x2 = @import("mat2x2.zig");
pub const Transform = @import("transform.zig");

pub fn rad(deg: f32) f32 {
    return deg * std.math.pi / 180.0;
}

pub fn clamp(v: f32, lower: f32, upper: f32) f32 {
    return std.math.min(std.math.max(v, lower), upper);
}

pub fn clamp_zo(v: f32) f32 {
    return clamp(v, 0.0, 1.0);
}
