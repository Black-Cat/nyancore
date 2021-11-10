usingnamespace @import("types.zig");

pub fn fromVec3(v: vec3, w: f32) vec4 {
    return .{ v[0], v[1], v[2], w };
}
