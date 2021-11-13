usingnamespace @import("types.zig");

pub fn mulv(m: mat2x2, v: vec2) vec2 {
    return .{
        m[0][0] * v[0] + m[1][0] * v[1],
        m[0][1] * v[0] + m[1][1] * v[1],
    };
}
