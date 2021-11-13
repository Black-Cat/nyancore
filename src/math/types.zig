const Vector = @import("std").meta.Vector;

pub const vec2 = Vector(2, f32);
pub const vec3 = Vector(3, f32);
pub const vec4 = Vector(4, f32);

pub const mat4x4 = [4]vec4;
pub const mat2x2 = [2]vec2;
