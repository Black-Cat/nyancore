const std = @import("std");

pub usingnamespace @import("types.zig");

pub const Vec3 = @import("vec3.zig");
pub const Vec4 = @import("vec4.zig");
pub const Mat4x4 = @import("mat4x4.zig");
pub const Transform = @import("transform.zig");

pub fn rad(deg: f32) f32 {
    return deg * std.math.pi / 180.0;
}
