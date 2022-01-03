const math = @import("math.zig");

pub fn fromVec3(v: math.vec3, w: f32) math.vec4 {
    return .{ v[0], v[1], v[2], w };
}
