usingnamespace @import("types.zig");

pub fn zeros() vec3 {
    const zero: f32 = 0.0;
    return @splat(3, zero);
}
